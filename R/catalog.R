# catalog.R
# Lista anos disponíveis no repositório HuggingFace da RAIS
#
# Estrutura real do repositório:
#   RAIS/{ano}/          — todos os anos (1985-2025)
#   RAIS/{ano} Parcial/  — versões parciais (ex: "2023 Parcial")
#   RAIS/Layouts/        — layouts/dicionários
#
# Distinção antigo/novo é feita pelos ARQUIVOS dentro de cada pasta:
#   < 2018: {UF}{ano}.7z, ESTB{ano}.7z   (por UF)
#   >= 2018: RAIS_VINC_PUB_*.7z           (por região)

#' Lista os anos disponíveis no repositório HuggingFace da RAIS
#'
#' Consulta a API do HuggingFace e retorna os anos disponíveis,
#' ordenados do mais recente para o mais antigo.
#'
#' @param type character. Série a consultar:
#'   `"vinculos"`, `"estabelecimentos"` ou `"domestico"`.
#'   Default: `"vinculos"`.
#' @param include_partial logical. Incluir anos com versão parcial
#'   (ex: `"2023 Parcial"`)? Default: `FALSE`.
#' @param n integer. Número de anos mais recentes a retornar.
#'   Use `Inf` para retornar todos. Default: `Inf`.
#' @param timeout integer. Timeout em segundos. Default: `15`.
#' @param verbose logical. Se `TRUE`, exibe tabela no console.
#'   Default: `TRUE`.
#'
#' @return tibble invisível com colunas `ano`, `layout`, `parcial` e
#'   `url_base`, ordenado do mais recente para o mais antigo.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   rais_available()
#'   rais_available(n = 5)
#'   rais_available(include_partial = TRUE)
#' }
#' }
#'
#' @seealso [rais_status()], [rais_load()]
#' @export
rais_available <- function(type            = "vinculos",
                            include_partial = FALSE,
                            n               = Inf,
                            timeout         = 15,
                            verbose         = TRUE) {
  type <- match.arg(type, c("vinculos", "estabelecimentos", "domestico"))

  cli::cli_inform(.tr(
    "Querying HuggingFace repository ({.url %s})...", .HF_API
  ))

  # Listar todas as subpastas de RAIS/
  itens <- .hf_list_dir(.HF_PASTA_RAIS, timeout)
  if (is.null(itens) || length(itens) == 0L) {
    cli::cli_warn(.tr(
      "No year found in the HuggingFace repository for type '%s'.", type
    ))
    return(invisible(tibble::tibble()))
  }

  ano_max <- as.integer(format(Sys.Date(), "%Y"))
  resultados <- list()

  for (nome in itens) {
    # Ignorar Layouts e arquivos
    if (grepl("^Layouts$|\\.", nome)) next

    # Detectar se é parcial: "2023 Parcial", "2024 Parcial"
    eh_parcial <- grepl("Parcial", nome, ignore.case = TRUE)
    if (eh_parcial && !include_partial) next

    # Extrair ano do nome ("2023", "2023 Parcial" → 2023)
    ano <- suppressWarnings(as.integer(
      regmatches(nome, regexpr("\\d{4}", nome))
    ))
    if (length(ano) == 0L || is.na(ano) || ano < 1985L || ano > ano_max + 1L) next

    layout <- if (ano >= .ANO_CORTE) "novo" else "antigo"

    resultados[[length(resultados) + 1L]] <- tibble::tibble(
      ano      = ano,
      layout   = layout,
      parcial  = eh_parcial,
      pasta    = nome,
      url_base = paste0(.HF_BASE, "/", .HF_PASTA_RAIS, "/",
                        utils::URLencode(nome, repeated = TRUE))
    )
  }

  if (length(resultados) == 0L) {
    cli::cli_warn(.tr(
      "No year found in the HuggingFace repository for type '%s'.", type
    ))
    return(invisible(tibble::tibble()))
  }

  resultado <- dplyr::bind_rows(resultados) |>
    dplyr::arrange(dplyr::desc(ano), parcial)

  if (!is.infinite(n)) resultado <- utils::head(resultado, as.integer(n))

  if (verbose && nrow(resultado) > 0L) {
    serie <- switch(type,
      vinculos         = .tr("Vinculos empregaticios"),
      estabelecimentos = .tr("Estabelecimentos"),
      domestico        = .tr("Trabalho domestico")
    )
    cli::cli_h2(.tr("Available years - %s", serie))
    for (i in seq_len(nrow(resultado))) {
      r <- resultado[i, ] # nolint: object_usage_linter.
      parcial_tag <- if (r$parcial) " [parcial]" else ""
      cli::cli_inform(
        "  {cli::col_cyan(as.character(r$ano))}  [{r$layout}]{parcial_tag}"
      )
    }
    cli::cli_inform(c(
      "i" = .tr("%d year(s) listed", nrow(resultado)),
      "i" = .tr(
        "Use {.code rais_load(years = %d)} to download the most recent.",
        resultado$ano[1]
      )
    ))
  }

  invisible(resultado)
}

#' List available years in the RAIS HuggingFace repository
#'
#' A convenience wrapper around [rais_available()] that returns only
#' the integer vector of available years.
#'
#' @param type character. `"vinculos"`, `"estabelecimentos"` or
#'   `"domestico"`. Default: `"vinculos"`.
#' @param include_partial logical. Include partial years? Default: `FALSE`.
#' @param timeout integer. Request timeout in seconds. Default: `15`.
#'
#' @return An integer vector of available years, sorted in ascending order.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   rais_available_years()
#'   rais_available_years(type = "estabelecimentos")
#' }
#' }
#'
#' @seealso [rais_available()] for the full catalog with layout and URL.
#' @export
rais_available_years <- function(type            = "vinculos",
                                  include_partial = FALSE,
                                  timeout         = 15) {
  res <- rais_available(
    type            = type,
    include_partial = include_partial,
    timeout         = timeout,
    verbose         = FALSE
  )
  sort(unique(res$ano))
}

# -- Helpers internos ----------------------------------------------------------

#' Lista o conteúdo de uma pasta no repositório HuggingFace via API
#' @noRd
.hf_list_dir <- function(path, timeout = 15) {
  url <- paste0(.HF_API, "/", utils::URLencode(path, repeated = TRUE))

  resp <- tryCatch({
    httr2::request(url) |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
  }, error = function(e) NULL)

  if (is.null(resp)) return(NULL)
  if (httr2::resp_status(resp) != 200L) return(NULL)

  parsed <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) NULL
  )
  if (is.null(parsed) || length(parsed) == 0L) return(NULL)

  vapply(parsed, function(item) {
    p <- item[["path"]]
    if (is.null(p) || !nzchar(p)) return(NA_character_)
    basename(p)
  }, character(1L)) |> {\(x) x[!is.na(x) & nzchar(x)]}()
}

#' Lista os arquivos disponíveis no HuggingFace para um ou mais anos
#'
#' Consulta a API do HuggingFace e retorna os arquivos `.7z` (e `.zip`)
#' disponíveis em `RAIS/<ano>/`, com tamanho, tipo e URL de download.
#' Equivalente funcional a `caged_ftp_files()` do pacote datacaged.
#' Usa o HuggingFace (não FTP) como fonte dos dados.
#'
#' @param years integer. Ano(s) a consultar. Default: ano atual.
#' @param type character. Filtrar por tipo: `"vinculos"`,
#'   `"estabelecimentos"`, `"all"`. Default: `"all"`.
#' @param include_partial logical. Incluir pastas parciais
#'   (ex: `"2023 Parcial"`)? Default: `FALSE`.
#' @param timeout integer. Timeout por requisição em segundos. Default: `15`.
#' @param verbose logical. Exibir progresso. Default: `TRUE`.
#'
#' @return tibble com colunas:
#'   - `ano` integer
#'   - `pasta` character — pasta no HF (`"2023"` ou `"2023 Parcial"`)
#'   - `arquivo` character — nome do arquivo
#'   - `tipo` character — `"vinculos"`, `"estab"` ou `"outro"`
#'   - `layout` character — `"antigo"` (1985-2017) ou `"novo"` (2018+)
#'   - `tamanho_mb` numeric — tamanho em MB
#'   - `url` character — URL de download
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Arquivos de 2023
#'   rais_hf_files(years = 2023)
#'
#'   # Só vínculos de 2022 e 2023
#'   rais_hf_files(years = 2022:2023, type = "vinculos")
#'
#'   # Ver tamanho total a baixar
#'   files <- rais_hf_files(years = 2023)
#'   sum(files$tamanho_mb)
#' }
#' }
#'
#' @seealso [rais_available()], [rais_download()]
#' @export
rais_hf_files <- function(years           = as.integer(format(Sys.Date(), "%Y")),
                           type            = "all",
                           include_partial = FALSE,
                           timeout         = 15,
                           verbose         = TRUE) {
  years <- .validate_years(years)
  type  <- match.arg(type, c("all", "vinculos", "estabelecimentos"))

  # Determinar pastas a consultar
  pastas <- list()
  for (year in years) {
    pastas[[length(pastas) + 1L]] <- list(ano = year, pasta = as.character(year))
    if (include_partial) {
      parcial <- paste(year, "Parcial")
      if (!is.na(.hf_ano_existe(parcial, timeout = timeout))) {
        pastas[[length(pastas) + 1L]] <- list(ano = year, pasta = parcial)
      }
    }
  }

  if (verbose && length(pastas) > 0L)
    cli::cli_inform(.tr(
      "Querying HuggingFace repository ({.url %s})...", .HF_API
    ))

  rows <- list()
  for (p in pastas) {
    ano   <- p$ano
    pasta <- p$pasta

    itens <- .hf_list_dir_full(
      paste0(.HF_PASTA_RAIS, "/", pasta), timeout
    )
    if (is.null(itens) || length(itens) == 0L) {
      if (verbose)
        cli::cli_warn("Nenhum arquivo encontrado em RAIS/{pasta}/")
      next
    }

    layout <- if (.is_rais_novo(ano)) "novo" else "antigo"

    for (item in itens) {
      nome <- basename(item$path)

      # Ignorar especiais
      if (.deve_ignorar(nome)) next
      # S\u00f3 .7z e .zip
      if (!grepl("\\.(7z|zip)$", nome, ignore.case = TRUE)) next

      # Detectar tipo
      tipo_arq <- dplyr::case_when(
        grepl("VINC|^[A-Z]{2}\\d{4}", nome)   ~ "vinculos",
        grepl("ESTAB|ESTB|^Estb", nome)        ~ "estab",
        TRUE                                    ~ "outro"
      )

      # Filtrar por tipo
      if (type == "vinculos"        && tipo_arq != "vinculos") next
      if (type == "estabelecimentos" && tipo_arq != "estab")    next

      tamanho_mb <- round(item$size / 1024 / 1024, 2)
      url_dl     <- paste0(
        .HF_BASE, "/",
        utils::URLencode(paste0(.HF_PASTA_RAIS, "/", pasta, "/", nome),
                         repeated = TRUE)
      )

      rows[[length(rows) + 1L]] <- tibble::tibble(
        ano         = ano,
        pasta       = pasta,
        arquivo     = nome,
        tipo        = tipo_arq,
        layout      = layout,
        tamanho_mb  = tamanho_mb,
        url         = url_dl
      )
    }
  }

  if (length(rows) == 0L) {
    if (verbose) cli::cli_inform("Nenhum arquivo encontrado.")
    return(invisible(tibble::tibble(
      ano = integer(), pasta = character(), arquivo = character(),
      tipo = character(), layout = character(),
      tamanho_mb = numeric(), url = character()
    )))
  }

  resultado <- dplyr::bind_rows(rows)

  if (verbose) {
    total_mb <- sum(resultado$tamanho_mb, na.rm = TRUE)
    cli::cli_inform(c(
      "v" = .tr("%d file(s) to process", nrow(resultado)),
      "i" = paste0("Total: ", round(total_mb, 1), " MB")
    ))
  }

  invisible(resultado)
}

#' Lista conteúdo completo de uma pasta no HF (com metadados de tamanho)
#' @noRd
.hf_list_dir_full <- function(path, timeout = 15) {
  url <- paste0(.HF_API, "/",
                utils::URLencode(path, repeated = TRUE))

  resp <- tryCatch({
    httr2::request(url) |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
  }, error = function(e) NULL)

  if (is.null(resp) || httr2::resp_status(resp) != 200L) return(NULL)

  parsed <- tryCatch(
    httr2::resp_body_json(resp),
    error = function(e) NULL
  )
  if (is.null(parsed)) return(NULL)

  # Retornar lista de items com path e size
  lapply(parsed, function(item) {
    list(
      path = item[["path"]] %||% "",
      size = item[["size"]] %||% 0L,
      type = item[["type"]] %||% "file"
    )
  })
}
