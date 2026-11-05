# parse.R
# Leitura e normaliza\u00e7\u00e3o dos microdados da RAIS
# Usa layouts.R para aplicar as regras corretas por per\u00edodo

# -- Detec\u00e7\u00e3o de tipo e ano ---------------------------------------------------

#' Detecta tipo de arquivo RAIS pelo nome
#' @return "vinculos_antigo","vinculos_novo","estab","estab_novo","domestico"
#' @noRd
.detect_rais_type <- function(path) {
  nome <- toupper(basename(path))
  if      (grepl("RAIS_DOM",      nome)) "domestico"
  else if (grepl("RAIS_ESTAB",    nome)) "estab_novo"
  else if (grepl("ESTB|RAIS_ESTB",nome)) "estab"
  else if (grepl("RAIS_VINC",     nome)) "vinculos_novo"
  else                                    "vinculos_antigo"
}

#' Extrai o ano do caminho do arquivo
#'
#' Procura primeiro no nome do arquivo (CE2015.7z → 2015),
#' depois no diretório pai.
#' @noRd
.extract_year <- function(path) {
  nome <- basename(path)
  # padr\u00e3o: {XX}AAAA.7z  ou  RAIS_VINC_PUB_XXX_AAAA.7z
  m_nome <- regmatches(nome, regexpr("\\d{4}", nome))
  if (length(m_nome) > 0L) {
    y <- as.integer(m_nome[1L])
    if (!is.na(y) && y >= 1985L && y <= 2030L) return(y)
  }
  # fallback: diret\u00f3rio pai
  m_dir <- regmatches(basename(dirname(path)), regexpr("\\d{4}", basename(dirname(path))))
  if (length(m_dir) > 0L) {
    y <- as.integer(m_dir[1L])
    if (!is.na(y) && y >= 1985L && y <= 2030L) return(y)
  }
  NA_integer_
}

# -- Leitura de um .txt -------------------------------------------------------

#' Lê e normaliza um arquivo .txt da RAIS com as regras do período correto
#' @noRd
.read_rais_txt <- function(path, type = NULL, year = NULL) {
  if (is.null(type)) type <- .detect_rais_type(path)
  if (is.null(year)) year <- .extract_year(path)

  # Contexto de parsing: encoding, cols num\u00e9ricas, etc.
  ctx <- if (!is.na(year)) .contexto_parsing(year) else list(
    encoding       = if (type %in% c("vinculos_novo","estab_novo")) "UTF-8" else "latin1",
    cols_numericas = .cols_numericas_periodo("v1994_2014")
  )

  df <- tryCatch(
    readr::read_delim(
      path,
      delim           = ";",
      locale          = readr::locale(encoding       = ctx$encoding,
                                       decimal_mark   = ",",
                                       grouping_mark  = "."),
      col_types       = readr::cols(.default = readr::col_character()),
      show_col_types  = FALSE,
      progress        = FALSE,
      name_repair     = "universal_quiet",
      skip_empty_rows = TRUE,
      trim_ws         = TRUE
    ),
    error = function(e) {
      # Fallback: tenta latin1 se UTF-8 falhar
      if (ctx$encoding == "UTF-8") {
        tryCatch(
          readr::read_delim(
            path, delim = ";",
            locale        = readr::locale(encoding = "latin1", decimal_mark = ","),
            col_types     = readr::cols(.default = readr::col_character()),
            show_col_types = FALSE, progress = FALSE,
            name_repair   = "universal_quiet", skip_empty_rows = TRUE, trim_ws = TRUE
          ),
          error = function(e2) {
            cli::cli_warn(.tr("Error reading {.path %s}: %s", path, conditionMessage(e2)))
            NULL
          }
        )
      } else {
        cli::cli_warn(.tr("Error reading {.path %s}: %s", path, conditionMessage(e)))
        NULL
      }
    }
  )

  if (is.null(df) || nrow(df) == 0L) return(NULL)

  # 1. BOM no primeiro nome (precau\u00e7\u00e3o antes do pipeline)
  names(df)[1L] <- gsub("\uFEFF", "", names(df)[1L], fixed = FALSE)

  # 2. Pipeline unificado de normaliza\u00e7\u00e3o:
  #    Tentativa 1: nome original no dict (case-sensitive)
  #    Tentativa 2: nome original no dict (case-insensitive)
  #    Tentativa 3: snake_clean + dict
  #    Tentativa 4: fallback snake_clean sem mapeamento
  #    Isso garante que "Faixa Hora Contrat" \u2192 "qtd_horas_contratadas"
  #    em vez de "faixa_hora_contrat" (bug do pipeline antigo).
  dict_type <- if (grepl("estab", type)) "estabelecimentos" else "vinculos"
  df <- .apply_normalize_pipeline(df, dict_type = dict_type, quiet = TRUE)

  # 3. Coerce colunas num\u00e9ricas para o per\u00edodo correto
  df <- .coerce_numeric(df, ctx$cols_numericas)

  # 4. Adiciona metadados
  df$fonte_tipo <- type
  if (!is.na(year)) df$ano <- year

  df
}

# .normalize_col_names() movida para normalize.R como .snake_clean()

#' Coerce colunas numéricas conhecidas para o período correto
#' Remove ponto de milhar ANTES de trocar vírgula decimal.
#' Ex: "2.500,50" → remove "." → "2500,50" → troca "," → "2500.50" → 2500.5
#' @noRd
.coerce_numeric <- function(df, cols) {
  for (col in intersect(names(df), cols)) {
    if (!is.numeric(df[[col]])) {
      s <- as.character(df[[col]])
      s <- gsub("\\.", "", s)        # remove ponto de milhar
      s <- gsub(",",    ".", s)      # troca v\u00edrgula decimal
      df[[col]] <- suppressWarnings(as.numeric(s))
    }
  }
  df
}

# -- Parse via stream ----------------------------------------------------------

#' Lê .7z via stream direto (sem extração para disco)
#' @noRd
.parse_via_stream <- function(path, type, year) {
  entries <- archive::archive(path)
  txts    <- entries$path[grepl("\\.(txt|csv)$", entries$path, ignore.case = TRUE)]
  if (length(txts) == 0L) {
    cli::cli_warn(.tr("No .txt found in {.path %s}.", basename(path)))
    return(NULL)
  }
  purrr::map(txts, function(entry) {
    con <- archive::archive_read(path, file = entry)
    on.exit(try(close(con), silent = TRUE))
    .read_rais_txt(con, type = type, year = year)
  })
}

#' Fallback: extrai .7z para disco e lê os .txt
#' @noRd
.parse_via_extract <- function(path, type, year) {
  tmp <- tempfile()
  on.exit(unlink(tmp, recursive = TRUE))
  dir.create(tmp)
  txts <- tryCatch(
    .extract_7z(path, exdir = tmp),
    error = function(e) cli::cli_abort(
      .tr("Failed to extract {.path %s}: %s", path, conditionMessage(e))
    )
  )
  if (length(txts) == 0L) {
    cli::cli_warn(.tr("No .txt found in {.path %s}. Skipping.", basename(path)))
    return(NULL)
  }
  purrr::map(txts, \(f) .read_rais_txt(f, type = type, year = year))
}

# -- Extra\u00e7\u00e3o de .7z ----------------------------------------------------------

#' @noRd
.extract_7z <- function(path, exdir) {
  # PPMd (RAIS antigo): exige 7-Zip; LZMA (2020+): archive funciona
  ok <- tryCatch({
    suppressWarnings(archive::archive_extract(path, dir = exdir))
    TRUE
  }, error = function(e) FALSE)
  if (ok) { txts <- .list_txt(exdir); if (length(txts) > 0L) return(txts) }

  ok2 <- tryCatch({
    utils::unzip(path, exdir = exdir, junkpaths = TRUE); TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (ok2) { txts <- .list_txt(exdir); if (length(txts) > 0L) return(txts) }

  exe <- .find_7zip()
  if (!is.null(exe)) {
    pn <- normalizePath(path,  winslash = "\\", mustWork = FALSE)
    en <- normalizePath(exdir, winslash = "\\", mustWork = FALSE)
    if (.Platform$OS.type == "windows") {
      ret <- tryCatch(
        shell(paste0('"', exe, '" e "', pn, '" "-o', en, '" -y'),
               intern = TRUE, mustWork = FALSE),
        error = function(e) structure(character(0L), status = 1L)
      )
    } else {
      ret <- tryCatch(
        system2(exe, args = c("e", shQuote(pn), paste0("-o", shQuote(en)), "-y"),
                stdout = TRUE, stderr = TRUE),
        error = function(e) structure(character(0L), status = 1L)
      )
    }
    if (as.integer(attr(ret, "status") %||% 0L) == 0L) {
      txts <- .list_txt(exdir); if (length(txts) > 0L) return(txts)
    }
  }

  cli::cli_abort(c(
    .tr("Failed to extract {.path %s}.", basename(path)),
    "i" = "PPMd (RAIS antigo) requires 7-Zip: {.url https://www.7-zip.org/download.html}",
    "i" = "LZMA (2020+) works without 7-Zip via archive::archive_extract()."
  ))
}

#' @noRd
.list_txt <- function(dir)
  list.files(dir, full.names = TRUE, pattern = "\\.txt$|\\.csv$", ignore.case = TRUE)

#' @noRd
.find_7zip <- function() {
  found <- Sys.which(c("7z", "7za", "7zz"))
  found <- found[nchar(found) > 0L]
  if (length(found) > 0L) return(unname(found[1L]))
  if (.Platform$OS.type == "windows") {
    cands <- c(
      "C:/Program Files/7-Zip/7z.exe",
      "C:/Program Files (x86)/7-Zip/7z.exe",
      file.path(Sys.getenv("LOCALAPPDATA"), "Programs/7-Zip/7z.exe"),
      file.path(Sys.getenv("RTOOLS45_HOME", "C:/rtools45"), "usr/bin/7z.exe"),
      file.path(Sys.getenv("RTOOLS44_HOME", "C:/rtools44"), "usr/bin/7z.exe")
    )
    for (c in cands) if (file.exists(c)) return(c)
  }
  NULL
}

# -- Fun\u00e7\u00f5es p\u00fablicas ---------------------------------------------------------

#' Lê microdados de um arquivo .7z da RAIS
#'
#' Lê os `.txt` internos via stream (sem extrair para disco) usando
#' `archive::archive_read()`. Em caso de falha, extrai para diretório
#' temporário como fallback.
#'
#' As regras de parsing (encoding, colunas numéricas, BOM) são aplicadas
#' automaticamente com base no ano detectado no nome do arquivo.
#'
#' @param path character. Caminho do arquivo `.7z`.
#' @param type character ou NULL. Tipo: `"vinculos_antigo"`,
#'   `"vinculos_novo"`, `"estab"`, `"estab_novo"` ou `"domestico"`.
#'   Se `NULL`, detecta pelo nome.
#' @param year integer ou NULL. Ano dos dados. Se `NULL`, detecta pelo nome.
#' @param incluir_ignorados logical. Incluir arquivos `IGNORADOS*.7z`
#'   (registros sem UF identificada)? Default: `FALSE`.
#'
#' @return tibble com os microdados normalizados, ou `NULL` se inválido.
#'
#' @section Sobre PPMd e 7-Zip:
#' Arquivos da RAIS antigo (1985–2019) usam compressão PPMd, que requer
#' o 7-Zip instalado. A RAIS novo (2020+) usa LZMA e funciona sem
#' dependências externas. Se 7-Zip não for encontrado, o pacote aborta
#' com mensagem de instalação.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   df <- rais_parse("~/Downloads/CE2022.7z")
#'   dplyr::glimpse(df)
#'
#'   # Forçando tipo e ano manualmente
#'   df <- rais_parse("meu_arquivo.7z", type = "vinculos_antigo", year = 2015)
#' }
#' }
#'
#' @seealso [rais_parse_batch()] para múltiplos arquivos.
#' @seealso [rais_layouts()] para ver diferenças entre períodos.
#' @export
rais_parse <- function(path, type = NULL, year = NULL,
                        incluir_ignorados = FALSE) {
  if (!file.exists(path))
    cli::cli_abort(.tr("File not found: {.path %s}", path))

  # Pula arquivos especiais (IGNORADOS, Aviso.txt, etc.)
  if (.deve_ignorar(path, incluir_ignorados)) {
    cli::cli_inform(.tr(
      "Skipping special file: {.path %s}", basename(path)
    ))
    return(invisible(NULL))
  }

  # Pula arquivos da pasta Legado (layout anterior; dados duplicados)
  if (.e_legado(path)) {
    cli::cli_inform(.tr(
      "Skipping Legado file (use main folder): {.path %s}", basename(path)
    ))
    return(invisible(NULL))
  }

  if (!tolower(tools::file_ext(path)) %in% c("7z", "zip"))
    cli::cli_abort(.tr(
      "Unsupported file extension: {.path %s}. Use .7z or .zip.",
      basename(path)
    ))

  type <- type %||% .detect_rais_type(path)
  year <- year %||% .extract_year(path)

  # Aviso sobre PPMd para anos antigos
  if (!is.na(year) && .usa_ppmd(year) && is.null(.find_7zip())) {
    cli::cli_warn(c(
      .tr("Year %d uses PPMd compression (pre-2020).", year),
      "i" = "Install 7-Zip to read this file: {.url https://www.7-zip.org}"
    ))
  }

  dfs <- tryCatch(
    .parse_via_stream(path, type, year),
    error = function(e) {
      cli::cli_warn(.tr(
        "Stream failed for {.path %s}: %s. Trying extraction...",
        basename(path), conditionMessage(e)
      ))
      .parse_via_extract(path, type, year)
    }
  )

  if (is.null(dfs) || length(dfs) == 0L) return(invisible(NULL))
  dfs_ok <- purrr::compact(dfs)
  if (length(dfs_ok) == 0L) return(invisible(NULL))
  dplyr::bind_rows(dfs_ok)
}

#' Lê e normaliza múltiplos arquivos .7z da RAIS
#'
#' @param paths character vector. Caminhos dos arquivos `.7z`.
#' @param incluir_ignorados logical. Incluir IGNORADOS? Default: `FALSE`.
#' @param .progress logical. Exibe barra de progresso. Default: `TRUE`.
#'
#' @return tibble empilhado ou `NULL`.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   cache <- tools::R_user_dir("datarais", "cache")
#'   arqs  <- list.files(file.path(cache, "RAIS_NOVO", "2022"), full.names = TRUE)
#'   df    <- rais_parse_batch(arqs)
#' }
#' }
#'
#' @seealso [rais_parse()] para arquivo individual.
#' @export
rais_parse_batch <- function(paths, incluir_ignorados = FALSE, .progress = TRUE) {
  ausentes <- paths[!file.exists(paths)]
  if (length(ausentes) > 0L)
    cli::cli_abort(.tr("File not found: {.path %s}",
                       paste(ausentes, collapse = ", ")))
  paths <- paths[file.size(paths) > 0L]
  if (length(paths) == 0L) {
    cli::cli_inform(.tr("No valid file to parse."))
    return(invisible(NULL))
  }
  cli::cli_h2(.tr("Reading %d file(s)...", length(paths)))

  dfs <- purrr::map(
    paths,
    \(p) tryCatch(
      rais_parse(p, incluir_ignorados = incluir_ignorados),
      error = function(e) {
        cli::cli_warn(.tr("Error in {.path %s}: %s", basename(p), conditionMessage(e)))
        NULL
      }
    ),
    .progress = .progress
  )
  dfs <- purrr::compact(dfs)
  if (length(dfs) == 0L) { cli::cli_warn(.tr("No data read.")); return(invisible(NULL)) }

  resultado <- dplyr::bind_rows(dfs)
  cli::cli_inform(c(
    "v" = .tr("%s records read", format(nrow(resultado), big.mark = ",")),
    "i" = .tr("%d columns", ncol(resultado))
  ))
  resultado
}
