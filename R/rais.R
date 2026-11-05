#' datarais: Microdados da RAIS em DuckDB
#'
#' \if{html}{\figure{logo.png}{options: style='float: right' alt='datarais logo' width='120'}}
#'
#' @description
#' O pacote `datarais` facilita o acesso aos microdados da RAIS
#' (Relação Anual de Informações Sociais), cobrindo:
#'
#' - **RAIS antigo** (1985–2017): um arquivo por UF por ano
#' - **RAIS novo** (2018+): arquivos por região geográfica
#' - **Trabalho Doméstico** (2015+): série específica para domésticas
#'
#' Os dados são baixados do repositório HuggingFace
#' (`https://huggingface.co/datasets/alexsandroprado/rais`),
#' extraídos de arquivos `.7z` e carregados em um banco DuckDB local
#' para consultas rápidas com SQL ou dplyr.
#'
#' @section Fluxo típico de uso:
#' ```r
#' library(datarais)
#'
#' # Baixa, parseia e grava em um comando
#' rais_load(
#'   years   = 2022:2023,
#'   db_path = "minha_rais.duckdb"
#' )
#'
#' # Conecta e consulta
#' con <- rais_connect("minha_rais.duckdb")
#' dplyr::tbl(con, "rais_novo") |>
#'   dplyr::filter(ano == 2022, sigla_uf == 23L) |>  # 23 = CE
#'   dplyr::summarise(n = dplyr::n(),
#'                    salario = mean(vl_remun_media_nom, na.rm = TRUE))
#' ```
#'
#' @section Funções principais:
#' - `rais_load()`: pipeline completo (download -> parse -> DuckDB)
#' - `rais_download()`: só baixa os arquivos .7z
#' - `rais_parse()`: lê e normaliza um arquivo `.7z`
#' - `rais_parse_batch()`: lê e normaliza múltiplos arquivos `.7z`
#' - `rais_to_duckdb()`: grava um data.frame no banco
#' - `rais_connect()`: abre conexão com o banco DuckDB
#' - `rais_info()`: lista tabelas e registros disponíveis
#' - `rais_update()`: atualiza o banco com anos faltantes
#' - `rais_to_parquet()`: exporta tabelas para Parquet
#' - `rais_status()`: verifica se o repositório HuggingFace está acessível
#' - `rais_available()`: lista anos disponíveis no HuggingFace
#'
#' @section Tabelas no DuckDB:
#' | Tabela | Fonte no HF (`RAIS/<ano>/`) | Período |
#' |---|---|---|
#' | `rais_antigo` | `<UF><ano>.7z` | 1985–2017 |
#' | `rais_novo` | `RAIS_VINC_PUB_<regiao>.7z` | 2018+ |
#' | `rais_estab` | `ESTB<ano>.7z` / `RAIS_ESTAB_PUB.7z` | 1985+ |
#'
#' @docType package
#' @name datarais-package
#' @aliases datarais
#'
#' @importFrom cli cli_abort cli_inform cli_warn cli_h1 cli_h2
#'   cli_progress_bar cli_progress_done cli_progress_update
#'   col_blue col_cyan col_green col_red col_silver col_yellow
#'   pb_bar pb_current pb_elapsed pb_eta_str pb_total
#'   style_bold num_ansi_colors
#' @importFrom DBI dbConnect dbDisconnect dbGetQuery dbExecute dbListTables
#'   dbListFields dbExistsTable dbAppendTable
#'   dbSendQuery dbSendStatement dbBind dbFetch dbClearResult
#' @importFrom dplyr bind_rows filter pull count arrange collect
#'   group_by summarise mutate left_join desc tbl across all_of
#' @importFrom dbplyr remote_name
#' @importFrom duckdb duckdb
#' @importFrom furrr future_map furrr_options
#' @importFrom future plan multisession
#' @importFrom glue glue
#' @importFrom httr2 request req_perform req_error req_timeout
#'   req_retry resp_status resp_body_json resp_body_raw
#' @importFrom progressr progressor with_progress
#' @importFrom purrr map walk2 compact
#' @importFrom readr read_delim cols col_character locale
#' @importFrom rlang `%||%`
#' @importFrom tibble tibble
#' @importFrom utils download.file unzip packageVersion head globalVariables
#' @importFrom archive archive archive_extract archive_read
"_PACKAGE"

# -- Constantes internas -------------------------------------------------------

#' @noRd
.HF_REPO <- "alexsandroprado/rais"

#' @noRd
.HF_BASE <- "https://huggingface.co/datasets/alexsandroprado/rais/resolve/main"

#' @noRd
.HF_API <- "https://huggingface.co/api/datasets/alexsandroprado/rais/tree/main"

#' @noRd
# Todos os anos estao em RAIS/{ano}/ (nao ha pastas separadas antigo/novo)
.HF_PASTA_RAIS    <- "RAIS"
.HF_PASTA_LAYOUTS <- "RAIS/Layouts"

# Aliases para compatibilidade interna
.HF_PASTA_ANTIGO    <- "RAIS"
.HF_PASTA_NOVO      <- "RAIS"

#' Ano de corte: <= 2017 usa layout por UF; >= 2018 usa layout por região
#' @noRd
.ANO_CORTE <- 2018L

#' Regiões do layout novo (2018+)
#' @noRd
.REGIOES_NOVO <- c("CENTRO_OESTE", "MG_ES_RJ", "NORDESTE", "NORTE", "SP", "SUL")
.REGIAO_NI    <- "NI"   # n\u00e3o identificados, dispon\u00edvel a partir de 2022

#' UFs brasileiras
#' @noRd
.UF_CODIGOS <- c(
  RO = 11L, AC = 12L, AM = 13L, RR = 14L, PA = 15L, AP = 16L, TO = 17L,
  MA = 21L, PI = 22L, CE = 23L, RN = 24L, PB = 25L, PE = 26L, AL = 27L,
  SE = 28L, BA = 29L, MG = 31L, ES = 32L, RJ = 33L, SP = 35L, PR = 41L,
  SC = 42L, RS = 43L, MS = 50L, MT = 51L, GO = 52L, DF = 53L
)

# -- Valida\u00e7\u00f5es ----------------------------------------------------------------

#' @noRd
.validate_years <- function(years) {
  if (!is.numeric(years) || length(years) == 0L)
    cli::cli_abort(c(
      .tr("Invalid {.arg years} argument."),
      "i" = .tr("Provide a numeric vector of years between 1985 and %d.",
                 as.integer(format(Sys.Date(), "%Y")))
    ))
  if (anyNA(years))
    cli::cli_abort(.tr("{.arg years} contains NA values."))
  ano_max <- as.integer(format(Sys.Date(), "%Y"))
  invalid <- years[years < 1985L | years > ano_max + 1L]  # +1: anos parciais do proximo ano
  if (length(invalid) > 0)
    cli::cli_abort(c(
      .tr("Invalid years: {.val {invalid}}"),
      "i" = .tr("Provide years between 1985 and %d.", ano_max + 1L)
    ))
  as.integer(years)
}

#' @noRd
.validate_states <- function(states) {
  if (is.null(states)) return(NULL)
  states <- toupper(trimws(states))
  invalid <- setdiff(states, names(.UF_CODIGOS))
  if (length(invalid) > 0)
    cli::cli_abort(c(
      .tr("Invalid state(s): {.val {invalid}}"),
      "i" = .tr("Use two-letter codes: {.val {names(.UF_CODIGOS)}}")
    ))
  states
}

# -- Helpers -------------------------------------------------------------------

#' @noRd
.is_rais_novo <- function(year) year >= .ANO_CORTE

#' @noRd
.cache_dir <- function(destdir = NULL) {
  dir <- destdir %||% getOption("datarais.cache_dir",
                                 file.path(tempdir(), "datarais"))
  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)
  dir
}

#' @noRd
.is_cached <- function(destfile) {
  file.exists(destfile) && file.size(destfile) > 0L
}

#' @noRd
.disconnect <- function(con) {
  tryCatch(DBI::dbDisconnect(con, shutdown = TRUE),
           error = function(e) invisible(NULL))
}

# -- Supress\u00e3o de NOTEs do R CMD check ----------------------------------------
utils::globalVariables(c(
  "status", "arquivo", "ano", "uf", "regiao", "type",
  "n", "cnt", "sigla_uf", "parcial", "tabela"
))

# -- Startup -------------------------------------------------------------------

#' @noRd
.onAttach <- function(libname, pkgname) {
  ver  <- utils::packageVersion("datarais")
  repo <- paste0("https://huggingface.co/datasets/", .HF_REPO)

  if (cli::num_ansi_colors(stdout()) > 1L) {
    titulo <- paste0(
      cli::col_cyan(cli::style_bold("datarais")), " ", ver,
      " - Microdados da RAIS em DuckDB"
    )
    src   <- cli::col_silver(paste0("Fonte: ", repo))
    dicas <- cli::col_silver(paste0(
      "  Verifique a conex\u00e3o : rais_status()\n",
      "  Uso r\u00e1pido         : rais_load(years = 2023, db_path = \"rais.duckdb\")\n",
      "  Anos dispon\u00edveis  : rais_available()\n",
      "  Ajuda             : help(package = \"datarais\") | ?rais_load"
    ))
  } else {
    titulo <- paste0("datarais ", ver, " - Microdados da RAIS em DuckDB")
    src    <- paste0("Fonte: ", repo)
    dicas  <- paste0(
      "  rais_status() | rais_load(years = 2023) | rais_available()"
    )
  }

  packageStartupMessage("\n", titulo, "\n", src, "\n", dicas, "\n")
}
