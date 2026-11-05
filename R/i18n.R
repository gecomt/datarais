# =============================================================
# R/i18n.R
# Internationalisation (i18n) for datarais
#
# Primary language: English (en)
# Available translations: Brazilian Portuguese (pt_BR)
#
# Translation files:
#   po/datarais.pot   \u2014 template (English source strings)
#   po/pt_BR.po       \u2014 Brazilian Portuguese translations
#
# Runtime: translations are embedded in .TRANS_PT for zero
# external dependencies. The .po files are the canonical
# source of truth; .TRANS_PT is generated from them.
#
# Language selection priority:
#   1. RAIS_LANGUAGE environment variable
#   2. rais_set_language() session override
#   3. LANGUAGE / LC_MESSAGES / LC_ALL / LANG (OS locale)
#   4. Default: "en" (English)
# =============================================================

# -- Portuguese (pt_BR) translations ------------------------------------------
# Source of truth: po/pt_BR.po
# Regenerate with: msgfmt po/pt_BR.po -o inst/po/pt_BR/LC_MESSAGES/datarais.mo

#' @noRd
.TRANS_PT <- list(
  # catalog.R
  "Querying HuggingFace repository ({.url %s})..."
    = "Consultando reposit\u00f3rio HuggingFace ({.url %s})...",
  "No year found in the HuggingFace repository for type '%s'."
    = "Nenhum ano encontrado no HuggingFace para o tipo '%s'.",
  "Vinculos empregaticios"       = "V\u00ednculos empregat\u00edcios",
  "Estabelecimentos"             = "Estabelecimentos",
  "Trabalho domestico"           = "Trabalho Dom\u00e9stico",
  "Available years - %s"         = "Anos dispon\u00edveis - %s",
  "%d year(s) listed"            = "%d ano(s) listado(s)",
  "Use {.code rais_load(years = %d)} to download the most recent."
    = "Use {.code rais_load(years = %d)} para baixar o mais recente.",
  "Available: {.val {tabs_disponiveis}}"
    = "Dispon\u00edveis: {.val {tabs_disponiveis}}",

  # status.R
  "HuggingFace repository %s"    = "Reposit\u00f3rio HuggingFace %s",
  "Latency: %d ms"               = "Lat\u00eancia: %d ms",
  "Dataset: {.url %s}"           = "Dataset: {.url %s}",
  "Tested: {.url %s}"            = "Testado: {.url %s}",
  "Check your connection or try again later."
    = "Verifique sua conex\u00e3o ou tente novamente.",

  # download.R
  "No valid year/file to download."
    = "Nenhum ano/arquivo v\u00e1lido para download.",
  "Download RAIS Microdata"      = "Download Microdados RAIS",
  "%d file(s) to process"        = "%d arquivo(s) a processar",
  "Cache: {.path %s}"            = "Cache: {.path %s}",
  "Workers: %d"                  = "Workers: %d",
  "Downloading"                  = "Baixando",
  "Summary"                      = "Resumo",
  "Download RAIS layouts"        = "Download layouts RAIS",
  "Listing - %s"                 = "Listando - %s",
  "No layout found in {.url %s}."
    = "Nenhum layout encontrado em {.url %s}.",
  "Downloading %s"               = "Baixando %s",
  "Failed to download {.url %s} after 3 attempts."
    = "Falha ao baixar {.url %s} ap\u00f3s 3 tentativas.",

  # parse.R
  "Error reading {.path %s}: %s" = "Erro ao ler {.path %s}: %s",
  "No .txt found in {.path %s}." = "Nenhum .txt encontrado em {.path %s}.",
  "No .txt found in {.path %s}. Skipping."
    = "Nenhum .txt em {.path %s}. Pulando.",
  "Failed to extract {.path %s}: %s"
    = "Falha ao extrair {.path %s}: %s",
  "Failed to extract {.path %s}."
    = "Falha ao extrair {.path %s}.",
  "Stream failed for {.path %s}: %s. Trying extraction..."
    = "Stream falhou em {.path %s}: %s. Tentando extra\u00e7\u00e3o...",
  "No valid file to parse."      = "Nenhum arquivo v\u00e1lido para parsear.",
  "Reading %d file(s)..."        = "Lendo %d arquivo(s)...",
  "Error in {.path %s}: %s"     = "Erro em {.path %s}: %s",
  "No data read."                = "Nenhum dado lido.",
  "%s records read"              = "%s registros lidos",
  "%d columns"                   = "%d colunas",
  "Skipping special file: {.path %s}"
    = "Pulando arquivo especial: {.path %s}",
  "Skipping Legado file (use main folder): {.path %s}"
    = "Pulando arquivo Legado (use pasta principal): {.path %s}",
  "Year %d uses PPMd compression (pre-2020)."
    = "Ano %d usa compress\u00e3o PPMd (anterior a 2020).",
  "File not found: {.path %s}"  = "Arquivo n\u00e3o encontrado: {.path %s}",
  "Skipping %d preliminary file(s): the full release is available." = "Ignorando %d arquivo(s) preliminar(es): a vers\u00e3o completa est\u00e1 dispon\u00edvel.",
  "Unsupported file extension: {.path %s}. Use .7z or .zip." = "Extens\u00e3o de arquivo n\u00e3o suportada: {.path %s}. Use .7z ou .zip.",

  # database.R
  "Connected to {.path %s}"     = "Conectado a {.path %s}",
  "Empty data.frame - nothing to write."
    = "Data.frame vazio - nada a gravar.",
  "{.arg db_path} or {.arg .con} must be provided."
    = "{.arg db_path} ou {.arg .con} \u00e9 obrigat\u00f3rio.",
  "Column {.col ano} not found in the data.frame."
    = "Coluna {.col ano} n\u00e3o encontrada no data.frame.",
  "Empty data.frame after cleaning - nothing to write."
    = "Data.frame vazio ap\u00f3s limpeza - nada a gravar.",
  "%d year(s) already in DB - skipping."
    = "%d ano(s) j\u00e1 no banco - pulando.",
  "Use {.code overwrite_years = TRUE} to force."
    = "Use {.code overwrite_years = TRUE} para for\u00e7ar.",
  "No new data to insert."       = "Nenhum dado novo para inserir.",
  "%s record(s) inserted in {.val %s}"
    = "%s registro(s) inserido(s) em {.val %s}",
  "No RAIS table found in {.path %s}."
    = "Nenhuma tabela RAIS em {.path %s}.",
  "datarais - {.path %s}"       = "datarais - {.path %s}",
  "File size: %s"                = "Tamanho do arquivo: %s",
  "Tables"                       = "Tabelas",
  "Records : %s"                 = "Registros : %s",
  "Years   : %s"                 = "Anos      : %s",
  "rais_load"                    = "rais_load",
  "Years: %d-%d"                 = "Anos: %d-%d",
  "Type : %s"                    = "Tipo : %s",
  "DB   : {.path %s}"           = "Banco: {.path %s}",
  "1/3  Download"                = "1/3  Download",
  "No files available to process."
    = "Nenhum arquivo dispon\u00edvel para processar.",
  "2/3  Parse and load into DuckDB"
    = "2/3  Parsear e carregar no DuckDB",
  "Files"                        = "Arquivos",
  "3/3  Done"                    = "3/3  Conclu\u00eddo",
  "Total inserted: %s records"   = "Total inserido: %s registros",
  "rais_update"                  = "rais_update",
  "Failed to query HuggingFace: %s"
    = "Falha ao consultar HuggingFace: %s",
  "No year found in HuggingFace."
    = "Nenhum ano encontrado no HuggingFace.",
  "Database already up to date." = "Banco de dados j\u00e1 atualizado.",
  "Max in DB: %d | Available: %d"
    = "M\u00e1x no banco: %d | Dispon\u00edvel: %d",
  "%d new year(s) found"         = "%d ano(s) novo(s) encontrado(s)",
  "Period: %d - %d"              = "Per\u00edodo: %d - %d",
  "Exporting to Parquet"         = "Exportando para Parquet",
  "%d table(s) to export"        = "%d tabela(s) para exportar",
  "Output: {.path %s}"          = "Sa\u00edda: {.path %s}",
  "{tab}: %s records \u2192 {.path %s}"
    = "{tab}: %s registros \u2192 {.path %s}",
  "Error exporting %s: %s"       = "Erro ao exportar %s: %s",
  "Done"                         = "Conclu\u00eddo",
  "%d table(s) exported"         = "%d tabela(s) exportada(s)",
  "Column {.col fonte_tipo} not found."
    = "Coluna {.col fonte_tipo} n\u00e3o encontrada.",
  "Provide {.arg table} manually."
    = "Informe {.arg table} manualmente.",
  "Data frame mixes RAIS types: {.val {tipo}}."
    = "Data.frame mistura tipos RAIS: {.val {tipo}}.",
  "Parse and write each type separately."
    = "Processe e grave cada tipo separadamente.",
  "Unknown type: {.val {tipo}}"  = "Tipo desconhecido: {.val {tipo}}",
  "Table {.val %s} created with canonical schema (%d columns)."
    = "Tabela {.val %s} criada com schema can\u00f4nico (%d colunas).",
  "Database not found: {.path %s}"
    = "Banco de dados n\u00e3o encontrado: {.path %s}",
  "No canonical schema for table {.val %s}."
    = "Schema can\u00f4nico n\u00e3o encontrado para tabela {.val %s}.",
  "New column {.col %s} added to {.val %s} as %s."
    = "Nova coluna {.col %s} adicionada a {.val %s} como %s.",
  "Could not add column {.col %s}: %s"
    = "N\u00e3o foi poss\u00edvel adicionar coluna {.col %s}: %s",
  "Table(s) not found: {.val {invalidas}}"
    = "Tabela(s) n\u00e3o encontrada(s): {.val {invalidas}}",
  "{tab}: already exists. Use {.code overwrite = TRUE}."
    = "{tab}: j\u00e1 existe. Use {.code overwrite = TRUE}.",
  "Directory created: {.path %s}"
    = "Diret\u00f3rio criado: {.path %s}",

  # schema.R
  "No canonical schema for table {.val %s}."
    = "Schema can\u00f4nico n\u00e3o encontrado para tabela {.val %s}.",

  # rename.R
  "%d unrecognised column(s) kept as-is: %s"
    = "%d coluna(s) n\u00e3o reconhecida(s) mantida(s): %s",
  "%d unrecognised column(s) dropped: %s"
    = "%d coluna(s) n\u00e3o reconhecida(s) removida(s): %s",
  "  %s \u2192 %s"              = "  %s \u2192 %s",
  "  Could not rename %s: %s"   = "  N\u00e3o foi poss\u00edvel renomear %s: %s",
  "%d column(s) renamed in table '%s'"
    = "%d coluna(s) renomeada(s) na tabela '%s'",
  "Kept unchanged: %s"          = "Mantida(s) sem altera\u00e7\u00e3o: %s",
  "Table '%s' not found in the database."
    = "Tabela '%s' n\u00e3o encontrada no banco.",

  # rais.R (validation)
  "Invalid {.arg years} argument."
    = "Argumento {.arg years} inv\u00e1lido.",
  "Provide a numeric vector of years between 1985 and %d."
    = "Informe um vetor num\u00e9rico de anos entre 1985 e %d.",
  "{.arg years} contains NA values."
    = "{.arg years} cont\u00e9m valores NA.",
  "Invalid years: {.val {invalid}}"
    = "Anos inv\u00e1lidos: {.val {invalid}}",
  "Provide years between 1985 and %d."
    = "Informe anos entre 1985 e %d.",
  "Invalid state(s): {.val {invalid}}"
    = "UF(s) inv\u00e1lida(s): {.val {invalid}}",
  "Use two-letter codes: {.val {names(.UF_CODIGOS)}}"
    = "Use siglas de duas letras: {.val {names(.UF_CODIGOS)}}",

  # layouts.R
  "Layouts da RAIS por per\u00edodo"
    = "Layouts da RAIS por per\u00edodo",
  "V\u00ednculos"               = "V\u00ednculos",

  # i18n.R (rais_set_language / rais_language)
  "Language reset to automatic (OS locale)."
    = "Idioma redefinido para autom\u00e1tico (locale do SO).",
  "Unsupported language '%s'. Use \"en\" or \"pt\"."
    = "Idioma n\u00e3o suportado '%s'. Use \"en\" ou \"pt\".",
  "Language set to: %s"         = "Idioma definido: %s",
  "Active language: {label} [{source}]"
    = "Idioma ativo: {label} [{source}]",
  "OS locale (automatic)"       = "Locale do SO (autom\u00e1tico)"

  # Entradas complementares

)

# -- Language detection --------------------------------------------------------

#' @noRd
.detect_language <- function() {
  # 1. Package-specific env var (highest priority)
  env <- Sys.getenv("RAIS_LANGUAGE", unset = "")
  if (nchar(env) > 0L) return(.normalise_lang(env))

  # 2. Session override via rais_set_language()
  opt <- getOption("datarais.language", default = "")
  if (nchar(opt) > 0L) return(.normalise_lang(opt))

  # 3. GNU gettext standard (colon-separated list)
  env_lang <- Sys.getenv("LANGUAGE", unset = "")
  if (nchar(env_lang) > 0L)
    return(.normalise_lang(strsplit(env_lang, ":")[[1L]][1L]))

  # 4. POSIX locale variables
  for (var in c("LC_MESSAGES", "LC_ALL", "LANG")) {
    val <- Sys.getenv(var, unset = "")
    if (nchar(val) > 0L && !val %in% c("C", "POSIX"))
      return(.normalise_lang(val))
  }

  # 5. Windows fallback
  lc <- tryCatch(Sys.getlocale("LC_CTYPE"), error = function(e) "")
  if (nchar(lc) > 0L) return(.normalise_lang(lc))

  "en"  # default: English
}

#' @noRd
.normalise_lang <- function(locale) {
  locale <- sub("\\..+$", "", locale)  # strip encoding: "pt_BR.UTF-8" -> "pt_BR"
  locale <- sub("@.+$",    "", locale)  # strip modifier: "pt_BR@euro"  -> "pt_BR"
  lc     <- tolower(gsub("[-_]", "", locale))  # normaliza: "pt-BR" -> "ptbr"
  if (any(vapply(c("^pt", "^portuguese", "portugu"),
                 grepl, logical(1L), lc))) return("pt")
  "en"
}

# -- Core translation function -------------------------------------------------

#' Translate a message string
#'
#' Looks up `msgid` in the active language's dictionary and formats it
#' with `sprintf()` if additional arguments are supplied. Falls back to
#' the English source string when no translation is found.
#'
#' @param msgid  English source string (the lookup key).
#' @param ...    Values for `%s` / `%d` placeholders.
#' @param .lang  Override language (for testing). Default: auto-detected.
#' @noRd
.tr <- function(msgid, ..., .lang = .detect_language()) {
  msg <- if (.lang == "pt") .TRANS_PT[[msgid]] %||% msgid else msgid
  if (...length() > 0L) sprintf(msg, ...) else msg
}

# %||% importado de rlang via importFrom(rlang, `%||%`)

# -- Public API ----------------------------------------------------------------

#' Set the display language for datarais messages
#'
#' Overrides the OS locale for the current R session. The setting persists
#' until the session ends or `rais_set_language()` is called again. Supported
#' languages: `"en"` (English, default) and `"pt"` (Brazilian Portuguese).
#'
#' The language can also be set before starting R via the environment variable
#' `RAIS_LANGUAGE=pt` (or `RAIS_LANGUAGE=en`).
#'
#' @param lang `"en"` for English, `"pt"` for Brazilian Portuguese, or `NULL`
#'   to restore automatic detection from the OS locale.
#'
#' @return Invisibly returns the previous language code.
#'
#' @examples
#' rais_set_language("pt")   # switch to Portuguese
#' rais_set_language("en")   # switch to English
#' rais_set_language(NULL)   # restore OS locale detection
#'
#' @export
rais_set_language <- function(lang = NULL) {
  prev <- getOption("datarais.language", default = "")
  if (is.null(lang)) {
    options(datarais.language = NULL)
    cli::cli_alert_info(.tr("Language reset to automatic (OS locale)."))
  } else {
    lang <- .normalise_lang(as.character(lang))
    if (!lang %in% c("en", "pt"))
      cli::cli_abort(.tr("Unsupported language '%s'. Use \"en\" or \"pt\".", lang))
    options(datarais.language = lang)
    label <- if (lang == "pt") "Portugu\u00eas (pt_BR)" else "English (en)" # nolint: object_usage_linter.
    cli::cli_alert_success(.tr("Language set to: %s", label))
  }
  invisible(prev)
}

#' Show the active display language
#'
#' Reports which language datarais is using for messages and how it was
#' determined (OS locale, environment variable, or session override).
#'
#' @return Invisibly returns `"en"` or `"pt"`.
#'
#' @examples
#' rais_language()
#'
#' @export
rais_language <- function() {
  lang   <- .detect_language()
  source <- if (nchar(Sys.getenv("RAIS_LANGUAGE", "")) > 0L) { # nolint: object_usage_linter.
    "RAIS_LANGUAGE env var"
  } else if (nchar(getOption("datarais.language", "")) > 0L) {
    "rais_set_language()"
  } else {
    .tr("OS locale (automatic)")
  }
  label <- if (lang == "pt") "Portugu\u00eas (pt_BR)" else "English (en)" # nolint: object_usage_linter.
  cli::cli_alert_info(.tr("Active language: {label} [{source}]"))
  invisible(lang)
}

# -- Package hooks -------------------------------------------------------------
