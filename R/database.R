# database.R
# Grava\u00e7\u00e3o no DuckDB, conex\u00e3o e utilit\u00e1rios de consulta

# -- Conex\u00e3o -------------------------------------------------------------------

#' Abre uma conexão com o banco DuckDB da RAIS
#'
#' @param db_path character. Caminho do arquivo `.duckdb`.
#'   Use `":memory:"` para banco temporário em memória.
#' @param read_only logical. Abre somente leitura. Default: `FALSE`.
#' @param quiet logical. Suprime mensagem de conexão. Default: `FALSE`.
#'
#' @return objeto de conexão DBI.
#'
#' @examples
#' \donttest{
#' con <- rais_connect(file.path(tempdir(), "rais.duckdb"))
#' DBI::dbListTables(con)
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#'
#' @seealso [rais_info()] para listar tabelas.
#' @export
rais_connect <- function(db_path, read_only = FALSE, quiet = FALSE) {
  # Recent duckdb versions store extensions/secrets in ~/.duckdb by default;
  # keep them out of the user's home (CRAN policy) when the option exists.
  args <- list(dbdir = db_path, read_only = read_only)
  if ("shared_home" %in% names(formals(duckdb::duckdb)))
    args$shared_home <- FALSE
  drv <- do.call(duckdb::duckdb, args)
  con <- DBI::dbConnect(drv)
  if (!quiet) cli::cli_inform(.tr("Connected to {.path %s}", db_path))
  con
}

# -- Escrita no DuckDB ---------------------------------------------------------

#' Grava um data.frame de microdados da RAIS em uma tabela DuckDB
#'
#' Usa deduplicação por `ano`: se um ano já existe na tabela, ele é
#' pulado (útil para re-rodar o pipeline). Use `overwrite_years = TRUE`
#' para sobrescrever.
#'
#' Tabelas criadas automaticamente:
#' - `rais_antigo`   — vínculos 1985–2017
#' - `rais_novo`     — vínculos 2018+
#' - `rais_estab`    — estabelecimentos
#' - `rais_domestico`— trabalho doméstico
#'
#' @param df data.frame ou tibble. Resultado de `rais_parse()`.
#' @param db_path character ou NULL. Caminho do `.duckdb`.
#' @param table character ou NULL. Nome da tabela. Se NULL, detecta
#'   automaticamente pela coluna `fonte_tipo`.
#' @param overwrite_years logical. Se TRUE, apaga e regrava os anos do df.
#'   Default: `FALSE`.
#' @param .con objeto de conexão DBI (opcional). Se fornecido, `db_path`
#'   é ignorado e o chamador é responsável por fechar a conexão.
#' @param .check_years logical. Uso interno. Se `FALSE`, não verifica anos já
#'   gravados nem apaga anos (o chamador cuida disso), o que permite gravar
#'   vários arquivos do mesmo ano (UFs ou regiões). Default: `TRUE`.
#'
#' @return invisível: número de linhas inseridas.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   df <- rais_parse("CE2022.7z")
#'   rais_to_duckdb(df, db_path = file.path(tempdir(), "rais.duckdb"))
#' }
#' }
#'
#' @seealso [rais_parse()] para gerar o data.frame.
#' @seealso [rais_load()] para o pipeline completo.
#' @export
rais_to_duckdb <- function(df,
                            db_path        = NULL,
                            table          = NULL,
                            overwrite_years = FALSE,
                            .con           = NULL,
                            .check_years   = TRUE) {
  if (is.null(df) || nrow(df) == 0L) {
    cli::cli_inform(.tr("Empty data.frame - nothing to write."))
    return(invisible(0L))
  }

  table <- table %||% .detect_table_rais(df)

  if (!is.null(.con)) {
    con        <- .con
    fechar_con <- FALSE
  } else {
    if (is.null(db_path))
      cli::cli_abort(.tr("{.arg db_path} or {.arg .con} must be provided."))
    con        <- rais_connect(db_path, quiet = TRUE)
    fechar_con <- TRUE
    on.exit(if (fechar_con) .disconnect(con), add = TRUE)
  }

  # Garante coluna `ano`
  if (!"ano" %in% names(df)) {
    cli::cli_abort(.tr("Column {.col ano} not found in the data.frame."))
  }
  df$ano <- suppressWarnings(as.integer(df$ano))
  df     <- df[!is.na(df$ano), ]
  if (nrow(df) == 0L) {
    cli::cli_inform(.tr("Empty data.frame after cleaning - nothing to write."))
    return(invisible(0L))
  }

  anos <- unique(df$ano)

  if (!.check_years) {
    n_inserido <- .insert_rows(con, table, df)
  } else if (overwrite_years) {
    .delete_years(con, table, anos)
    n_inserido <- .insert_rows(con, table, df)
  } else {
    ja_gravados <- .existing_years(con, table, anos)
    novos       <- setdiff(anos, ja_gravados)

    if (length(ja_gravados) > 0L) {
      cli::cli_inform(c(
        "i" = .tr("%d year(s) already in DB - skipping.", length(ja_gravados)),
        "i" = .tr("Use {.code overwrite_years = TRUE} to force.")
      ))
    }
    if (length(novos) == 0L) {
      cli::cli_inform(.tr("No new data to insert."))
      return(invisible(0L))
    }
    df_novo    <- dplyr::filter(df, ano %in% novos)
    n_inserido <- .insert_rows(con, table, df_novo)
  }

  cli::cli_inform(c(
    "v" = .tr("%s record(s) inserted in {.val %s}",
              format(n_inserido, big.mark = ","), table)
  ))
  invisible(n_inserido)
}

# -- Info do banco -------------------------------------------------------------

#' Lista tabelas e estatísticas do banco DuckDB da RAIS
#'
#' @param db_path character. Caminho do `.duckdb`.
#'
#' @return tibble invisível com estatísticas por tabela.
#'
#' @examples
#' \donttest{
#' rais_info(file.path(tempdir(), "rais.duckdb"))
#' }
#'
#' @seealso [rais_connect()] para obter uma conexão DBI.
#' @export
rais_info <- function(db_path) {
  if (db_path != ":memory:" && !file.exists(db_path))
    cli::cli_abort(.tr("Database not found: {.path %s}", db_path))

  con <- rais_connect(db_path, read_only = TRUE, quiet = TRUE)
  on.exit(.disconnect(con), add = TRUE)

  tabs_rais <- intersect(
    DBI::dbListTables(con),
    c("rais_antigo", "rais_novo", "rais_estab", "rais_domestico")
  )
  if (length(tabs_rais) == 0L) {
    cli::cli_inform(.tr("No RAIS table found in {.path %s}.", db_path))
    return(invisible(tibble::tibble()))
  }

  stats <- purrr::map(tabs_rais, function(tab) {
    n <- DBI::dbGetQuery(
      con, glue::glue("SELECT COUNT(*) AS n FROM \"{tab}\"")
    )$n
    ano_range <- tryCatch({
      r <- DBI::dbGetQuery(
        con, glue::glue(
          "SELECT MIN(ano) AS min_a, MAX(ano) AS max_a FROM \"{tab}\""
        )
      )
      if (is.na(r$min_a)) "(empty)" else glue::glue("{r$min_a} - {r$max_a}")
    }, error = function(e) NA_character_)

    tibble::tibble(table = tab, registros = n, anos = ano_range)
  }) |> dplyr::bind_rows()

  tamanho_mb  <- if (db_path == ":memory:") NA_real_
                 else round(file.size(db_path) / 1024^2, 1)
  tamanho_str <- if (is.na(tamanho_mb)) "(in memory)"
                 else paste0(tamanho_mb, " MB")

  cli::cli_h1(.tr("datarais - {.path %s}", db_path))
  cli::cli_inform(.tr("File size: %s", tamanho_str))
  cli::cli_h2(.tr("Tables"))
  for (i in seq_len(nrow(stats))) {
    s <- stats[i, ]
    cli::cli_inform(c(
      "*" = "{.val {s$table}}",
      " " = .tr("Records : %s", format(s$registros, big.mark = ",")),
      " " = .tr("Years   : %s", s$anos)
    ))
  }

  invisible(stats)
}

# -- Pipeline principal: rais_load ---------------------------------------------

#' Pipeline completo: download → parse → DuckDB
#'
#' Combina `rais_download()`, `rais_parse()` e `rais_to_duckdb()`
#' em um único comando. É o jeito mais simples de popular o banco.
#'
#' @param years integer vector. Anos desejados.
#' @param type character. `"vinculos"`, `"estabelecimentos"` ou `"all"`.
#'   Default: `"vinculos"`.
#' @param state character vector ou NULL. UFs para o layout antigo (1985–2017).
#'   **Ignorado para 2018+**, pois os arquivos são por região geográfica.
#'   Filtre por UF após a carga: `dplyr::filter(sigla_uf == 23L)`.
#' @param db_path character. Caminho do banco DuckDB.
#'   Default: `file.path(tempdir(), "rais.duckdb")`.
#' @param destdir character ou NULL. Cache de arquivos `.7z`.
#' @param force_download logical. Re-baixa mesmo se em cache. Default: `FALSE`.
#' @param overwrite_years logical. Sobrescreve anos já no banco. Default: `FALSE`.
#' @param timeout integer. Timeout por arquivo (segundos). Default: `300`.
#' @param workers integer. Downloads paralelos. Default: `1` (sequencial); aumente via `workers` ou `options(datarais.workers = N)`.
#'
#' @return invisível: tibble com estatísticas do banco.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Vínculos de 2022
#'   rais_load(years = 2022, db_path = file.path(tempdir(), "rais.duckdb"))
#'
#'   # Conecta e consulta
#'   con <- rais_connect(file.path(tempdir(), "rais.duckdb"))
#'   dplyr::tbl(con, "rais_novo") |>
#'     dplyr::group_by(sigla_uf) |>
#'     dplyr::summarise(n = dplyr::n(), salario = mean(vl_remun_media_nom, na.rm = TRUE)) |>
#'     dplyr::collect()
#'   DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' }
#'
#' @seealso [rais_update()] para carga incremental.
#' @param include_partial logical. Incluir anos parciais
#'   (ex: `"2023 Parcial"` no HuggingFace)? Default: `FALSE`.
#' @seealso [rais_info()] para inspecionar o banco.
#' @export
rais_load <- function(years,
                      type             = "vinculos",
                      state            = NULL,
                      include_partial  = FALSE,
                      db_path          = file.path(tempdir(), "rais.duckdb"),
                      destdir          = NULL,
                      force_download   = FALSE,
                      overwrite_years  = FALSE,
                      timeout          = 300,
                      workers          = getOption("datarais.workers", .default_workers())) {
  years <- .validate_years(years)
  state <- .validate_states(state)
  type  <- match.arg(type, c("vinculos", "estabelecimentos", "all"))

  cli::cli_h1(.tr("rais_load"))
  cli::cli_inform(c(
    "i" = .tr("Years: %d-%d", years[1L], years[length(years)]),
    "i" = .tr("Type : %s",   paste(type, collapse = ", ")),
    "i" = .tr("DB   : {.path %s}", db_path)
  ))

  # 1. Download
  cli::cli_h2(.tr("1/3  Download"))
  manifest <- rais_download(
    years           = years,
    type            = type,
    state           = state,
    include_partial = include_partial,
    destdir         = destdir,
    force           = force_download,
    timeout         = timeout,
    workers         = workers
  )

  arqs_ok <- manifest |>
    dplyr::filter(status %in% c("baixado", "cache")) |>
    dplyr::pull(arquivo)

  if (length(arqs_ok) == 0L) {
    cli::cli_warn(.tr("No files available to process."))
    return(invisible(NULL))
  }

  # 2. Parse + DuckDB (uma conex\u00e3o para todo o loop)
  cli::cli_h2(.tr("2/3  Parse and load into DuckDB"))
  manifest_ok    <- dplyr::filter(manifest, status %in% c("baixado", "cache"))
  n_inserido_total <- 0L

  con_load <- rais_connect(db_path, quiet = TRUE)
  con_load_fechado <- FALSE
  on.exit({ if (!con_load_fechado) .disconnect(con_load) }, add = TRUE)

  # Year-level decisions are made once, before the file loop: a year is made
  # of many files (one per state or region), so it cannot be checked per file.
  manifest_ok <- .prepare_manifest_for_load(manifest_ok, con_load, overwrite_years)
  if (nrow(manifest_ok) == 0L) {
    .disconnect(con_load)
    con_load_fechado <- TRUE
    cli::cli_inform(.tr("No new data to insert."))
    return(invisible(rais_info(db_path)))
  }

  cli::cli_progress_bar(
    name   = .tr("Files"),
    total  = nrow(manifest_ok),
    format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_elapsed}]"
  )

  for (i in seq_len(nrow(manifest_ok))) {
    arq      <- manifest_ok$arquivo[i]
    file_type <- manifest_ok$type[i]

    df <- tryCatch(
      rais_parse(arq, type = file_type),
      error = function(e) {
        cli::cli_warn(.tr("Error in {.path %s}: %s",
                          basename(arq), conditionMessage(e)))
        NULL
      }
    )

    if (!is.null(df) && nrow(df) > 0L) {
      n <- rais_to_duckdb(df, .con = con_load, .check_years = FALSE)
      n_inserido_total <- n_inserido_total + n
    }
    rm(df)
    cli::cli_progress_update()
  }
  cli::cli_progress_done()

  # 3. Resumo \u2014 fechar con_load ANTES de rais_info (DuckDB n\u00e3o aceita 2 conex\u00f5es)
  .disconnect(con_load)
  con_load_fechado <- TRUE

  cli::cli_h2(.tr("3/3  Done"))
  cli::cli_inform(c(
    "v" = .tr("Total inserted: %s records",
              format(n_inserido_total, big.mark = ","))
  ))

  invisible(rais_info(db_path))
}

# -- Update incremental --------------------------------------------------------

#' Atualiza o banco com os anos mais recentes disponíveis
#'
#' Consulta o HuggingFace para descobrir os anos disponíveis,
#' compara com o máximo já no banco e baixa apenas o que está faltando.
#'
#' @param db_path character. Caminho do banco DuckDB.
#' @param type character. `"vinculos"`, `"estabelecimentos"` ou `"all"`.
#'   Default: `"vinculos"`.
#' @param destdir character ou NULL. Cache de arquivos `.7z`.
#' @param workers integer. Downloads paralelos. Default: `1` (sequencial); aumente via `workers` ou `options(datarais.workers = N)`.
#' @param timeout integer. Timeout por arquivo. Default: `300`.
#' @param verbose logical. Default: `TRUE`.
#'
#' @return invisível: tibble com estatísticas do banco, ou NULL se já atualizado.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   rais_update(db_path = file.path(tempdir(), "rais.duckdb"))
#' }
#' }
#'
#' @param include_partial logical. Incluir anos parciais
#'   (ex: `"2023 Parcial"`)? Default: `FALSE`.
#' @seealso [rais_load()] para carga inicial completa.
#' @seealso [rais_available()] para listar anos disponíveis.
#' @export
rais_update <- function(db_path,
                         type            = "vinculos",
                         include_partial = FALSE,
                         destdir         = NULL,
                         workers         = getOption("datarais.workers", .default_workers()),
                         timeout         = 300,
                         verbose         = TRUE) {
  type <- match.arg(type, c("vinculos", "estabelecimentos", "all"))
  if (!file.exists(db_path))
    cli::cli_abort(.tr("Database not found: {.path %s}", db_path))
  if (verbose) cli::cli_h1(.tr("rais_update"))

  # Mapeia tipo \u2192 tabelas DuckDB
  tabs_por_tipo <- list(
    vinculos         = c("rais_antigo", "rais_novo"),
    estabelecimentos = "rais_estab",
    all              = c("rais_antigo", "rais_novo", "rais_estab")
  )

  max_no_banco <- .max_anos_banco(db_path)

  disponiveis <- tryCatch(
    rais_available(type = if (type == "all") "vinculos" else type,
                   include_partial = include_partial,
                   verbose = FALSE, timeout = timeout),
    error = function(e) {
      cli::cli_warn(.tr("Failed to query HuggingFace: %s", conditionMessage(e)))
      NULL
    }
  )

  if (is.null(disponiveis) || nrow(disponiveis) == 0L) {
    if (verbose) cli::cli_inform(.tr("No year found in HuggingFace."))
    return(invisible(NULL))
  }

  tabs   <- tabs_por_tipo[[type]]
  pres   <- tabs[tabs %in% names(max_no_banco)]
  max_db <- if (length(pres) == 0L) 0L
            else max(unlist(max_no_banco[pres]), na.rm = TRUE)
  if (is.infinite(max_db) || is.na(max_db)) max_db <- 0L

  novos <- disponiveis[disponiveis$ano > max_db, ]

  if (nrow(novos) == 0L) {
    if (verbose) {
      cli::cli_inform(c(
        "v" = .tr("Database already up to date."),
        "i" = .tr("Max in DB: %d | Available: %d",
                  max_db, max(disponiveis$ano))
      ))
    }
    return(invisible(NULL))
  }

  if (verbose) {
    cli::cli_inform(c(
      "i" = .tr("%d new year(s) found", nrow(novos)),
      "i" = .tr("Period: %d - %d", min(novos$ano), max(novos$ano))
    ))
  }

  rais_load(
    years           = sort(unique(novos$ano)),
    type            = type,
    include_partial = include_partial,
    db_path         = db_path,
    destdir         = destdir,
    timeout         = timeout,
    workers         = workers
  )
}

# -- Exporta\u00e7\u00e3o Parquet --------------------------------------------------------

#' Exporta tabelas do banco DuckDB para arquivos Parquet
#'
#' Usa o mecanismo nativo `COPY TO ... (FORMAT PARQUET)` do DuckDB.
#' Muito mais rápido do que `collect()` + `arrow::write_parquet()`
#' para grandes volumes.
#'
#' @param db_path character. Caminho do `.duckdb`.
#' @param output_dir character. Diretório de saída.
#' @param tables character vector ou NULL. Tabelas a exportar.
#'   `NULL` exporta todas as tabelas RAIS presentes.
#' @param partition_by character ou NULL. Coluna para particionamento
#'   (ex: `"sigla_uf"` ou `"ano"`).
#' @param overwrite logical. Sobrescreve arquivos existentes. Default: `FALSE`.
#'
#' @return invisível: tibble com `tabela`, `arquivo` e `registros`.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   db <- file.path(tempdir(), "rais.duckdb")
#'   rais_load(years = 2022, db_path = db)
#'
#'   # Exportar todas as tabelas
#'   rais_to_parquet(db, output_dir = tempdir())
#'
#'   # Particionado por UF
#'   rais_to_parquet(db, output_dir = tempdir(),
#'                   tables = "rais_novo", partition_by = "sigla_uf")
#' }
#' }
#'
#' @seealso [rais_info()] para listar tabelas disponíveis.
#' @export
rais_to_parquet <- function(db_path,
                              output_dir,
                              tables       = NULL,
                              partition_by = NULL,
                              overwrite    = FALSE) {
  if (db_path != ":memory:" && !file.exists(db_path))
    cli::cli_abort(.tr("Database not found: {.path %s}", db_path))
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
    cli::cli_inform(.tr("Directory created: {.path %s}", output_dir))
  }

  con <- rais_connect(db_path, read_only = TRUE, quiet = TRUE)
  on.exit(.disconnect(con), add = TRUE)

  tabs_disponiveis <- intersect(
    DBI::dbListTables(con),
    c("rais_antigo", "rais_novo", "rais_estab", "rais_domestico")
  )
  if (length(tabs_disponiveis) == 0L)
    cli::cli_abort(.tr("No RAIS table found in {.path %s}.", db_path))

  tabs_exportar <- if (is.null(tables)) tabs_disponiveis else {
    invalidas <- setdiff(tables, tabs_disponiveis)
    if (length(invalidas) > 0L)
      cli::cli_abort(c(
        .tr("Table(s) not found: {.val {invalidas}}"),
        "i" = .tr("Available: {.val {tabs_disponiveis}}")
      ))
    tables
  }

  cli::cli_h1(.tr("Exporting to Parquet"))
  cli::cli_inform(c(
    "i" = .tr("%d table(s) to export", length(tabs_exportar)),
    "i" = .tr("Output: {.path %s}", output_dir)
  ))

  resultados <- purrr::map(tabs_exportar, function(tab) {
    n <- DBI::dbGetQuery(
      con, glue::glue("SELECT COUNT(*) AS n FROM \"{tab}\"")
    )$n

    if (!is.null(partition_by)) {
      destino <- file.path(output_dir, tab)
      if (overwrite && dir.exists(destino)) unlink(destino, recursive = TRUE)
      if (!dir.exists(destino)) dir.create(destino, recursive = TRUE)
      sql <- glue::glue(
        "COPY (SELECT * FROM \"{tab}\") TO '{destino}' ",
        "(FORMAT PARQUET, PARTITION_BY ({partition_by}), OVERWRITE_OR_IGNORE TRUE)"
      )
    } else {
      destino <- file.path(output_dir, paste0(tab, ".parquet"))
      if (file.exists(destino) && !overwrite) {
        cli::cli_inform(c(
          "i" = .tr("{tab}: already exists. Use {.code overwrite = TRUE}.")
        ))
        return(tibble::tibble(tabela = tab, arquivo = destino,
                              registros = NA_integer_, status = "pulado"))
      }
      sql <- glue::glue(
        "COPY (SELECT * FROM \"{tab}\") TO '{destino}' (FORMAT PARQUET)"
      )
    }

    tryCatch({
      DBI::dbExecute(con, sql)
      cli::cli_inform(c(
        "v" = .tr("{tab}: %s records \u2192 {.path %s}",
                  format(n, big.mark = ","), basename(destino))
      ))
      tibble::tibble(tabela = tab, arquivo = destino,
                     registros = n, status = "exportado")
    }, error = function(e) {
      cli::cli_warn(.tr("Error exporting %s: %s", tab, conditionMessage(e)))
      tibble::tibble(tabela = tab, arquivo = destino,
                     registros = NA_integer_, status = "erro")
    })
  }) |> dplyr::bind_rows()

  cli::cli_h2(.tr("Done"))
  cli::cli_inform(c(
    "v" = .tr("%d table(s) exported",
              sum(resultados$status == "exportado"))
  ))
  invisible(resultados)
}

# -- Helpers internos ----------------------------------------------------------

#' Detecta tabela DuckDB pelo campo fonte_tipo
#' @noRd
.detect_table_rais <- function(df) {
  if (!"fonte_tipo" %in% names(df))
    cli::cli_abort(c(
      .tr("Column {.col fonte_tipo} not found."),
      "i" = .tr("Provide {.arg table} manually.")
    ))
  tipo <- unique(df$fonte_tipo)
  if (length(tipo) > 1L)
    cli::cli_abort(c(
      .tr("Data frame mixes RAIS types: {.val {tipo}}."),
      "i" = .tr("Parse and write each type separately.")
    ))
  switch(tipo,
    vinculos_antigo = "rais_antigo",
    vinculos_novo   = "rais_novo",
    estab           = ,          # antigo (por UF)
    estab_novo      = "rais_estab",  # novo (por regi\u00e3o)
    domestico       = "rais_domestico",
    cli::cli_abort(.tr("Unknown type: {.val {tipo}}"))
  )
}

#' Table that receives each downloaded file type
#' @noRd
.table_from_type <- function(type) {
  unname(c(vinculos_antigo = "rais_antigo",
           vinculos_novo   = "rais_novo",
           estab           = "rais_estab",
           estab_novo      = "rais_estab",
           domestico       = "rais_domestico")[type])
}

#' Decides, per (table, year), which downloaded files will be loaded
#'
#' * a preliminary ("Parcial") file is dropped when the full release of the
#'   same year and table is also in the manifest;
#' * years already in the database are skipped, or deleted first when
#'   `overwrite_years = TRUE`.
#' @noRd
.prepare_manifest_for_load <- function(manifest, con, overwrite_years = FALSE) {
  if (nrow(manifest) == 0L) return(manifest)
  manifest$tabela  <- .table_from_type(manifest$type)
  manifest$parcial <- grepl("Parcial", manifest$arquivo, fixed = TRUE)

  # 1. Full release supersedes the preliminary one
  chave   <- paste(manifest$tabela, manifest$ano)
  tem_cheio <- chave %in% chave[!manifest$parcial]
  descartar <- manifest$parcial & tem_cheio
  if (any(descartar))
    cli::cli_inform(.tr("Skipping %d preliminary file(s): the full release is available.",
                        sum(descartar)))
  manifest <- manifest[!descartar, , drop = FALSE]

  # 2. Years already in the database
  for (tab in unique(manifest$tabela)) {
    anos <- unique(manifest$ano[manifest$tabela == tab])
    if (overwrite_years) {
      .delete_years(con, tab, anos)
    } else {
      ja <- .existing_years(con, tab, anos)
      if (length(ja) > 0L) {
        cli::cli_inform(c(
          "i" = .tr("%d year(s) already in DB - skipping.", length(ja)),
          "i" = .tr("Use {.code overwrite_years = TRUE} to force.")
        ))
        manifest <- manifest[!(manifest$tabela == tab & manifest$ano %in% ja), ,
                             drop = FALSE]
      }
    }
  }
  manifest
}

#' @noRd
.existing_years <- function(con, table, anos) {
  if (!DBI::dbExistsTable(con, table)) return(integer(0L))
  cols <- DBI::dbListFields(con, table)
  if (!"ano" %in% cols) return(integer(0L))
  if (length(anos) == 0L) return(integer(0L))
  placeholders <- paste(rep("?", length(anos)), collapse = ", ")
  sql <- sprintf("SELECT DISTINCT ano FROM \"%s\" WHERE ano IN (%s)",
                 table, placeholders)
  tryCatch({
    rs <- DBI::dbSendQuery(con, sql)
    on.exit(try(DBI::dbClearResult(rs), silent = TRUE), add = TRUE)
    DBI::dbBind(rs, as.list(as.integer(anos)))
    res <- DBI::dbFetch(rs)
    DBI::dbClearResult(rs)
    as.integer(res$ano)
  }, error = function(e) integer(0L))
}

#' @noRd
.delete_years <- function(con, table, anos) {
  if (length(anos) == 0L || !DBI::dbExistsTable(con, table)) return(invisible())
  placeholders <- paste(rep("?", length(anos)), collapse = ", ")
  sql <- sprintf("DELETE FROM \"%s\" WHERE ano IN (%s)", table, placeholders)
  rs <- DBI::dbSendStatement(con, sql)
  on.exit(try(DBI::dbClearResult(rs), silent = TRUE), add = TRUE)
  DBI::dbBind(rs, as.list(as.integer(anos)))
  DBI::dbClearResult(rs)
  invisible(NULL)
}

#' @noRd
.insert_rows <- function(con, table, df) {
  # 1. Cria a tabela com schema can\u00f4nico se n\u00e3o existir
  #    Garante tipos corretos independentemente do primeiro ano carregado
  if (!DBI::dbExistsTable(con, table)) {
    .create_table_canonical(con, table)
  }

  # 2. Alinha o df ao schema can\u00f4nico (tipos + colunas ausentes como NA)
  df <- .align_to_schema(df, table)

  # 3. Adiciona colunas extras do df que n\u00e3o est\u00e3o no schema can\u00f4nico
  #    (colunas imprevis\u00edveis de layouts futuros ou regionais)
  .sync_schema(con, table, df)

  # 4. Reordena df conforme colunas atuais do banco
  all_cols <- DBI::dbListFields(con, table)
  missing  <- setdiff(all_cols, names(df))
  for (col in missing) df[[col]] <- NA
  df <- df[, all_cols, drop = FALSE]

  DBI::dbAppendTable(con, table, df)
  nrow(df)
}

#' @noRd
.max_anos_banco <- function(db_path) {
  if (!file.exists(db_path)) return(list())
  con <- tryCatch(rais_connect(db_path, read_only = TRUE, quiet = TRUE),
                  error = function(e) NULL)
  if (is.null(con)) return(list())
  on.exit(.disconnect(con), add = TRUE)

  tabs <- intersect(DBI::dbListTables(con),
                    c("rais_antigo", "rais_novo", "rais_estab", "rais_domestico"))
  if (length(tabs) == 0L) return(list())

  result <- list()
  for (tab in tabs) {
    cols <- DBI::dbListFields(con, tab)
    if (!"ano" %in% cols) next
    max_val <- tryCatch(
      DBI::dbGetQuery(con, glue::glue(
        "SELECT MAX(ano) AS m FROM \"{tab}\""
      ))$m,
      error = function(e) NA_real_
    )
    result[[tab]] <- if (is.na(max_val)) 0L else as.integer(max_val)
  }
  result
}


#' Acessa uma tabela RAIS no DuckDB como lazy tibble
#'
#' Atalho para `dplyr::tbl(con, tabela)` que seleciona automaticamente
#' a tabela correta com base no ano ou tipo solicitado.
#'
#' @param con objeto de conexão DBI retornado por [rais_connect()].
#' @param year integer ou NULL. Se fornecido, seleciona `rais_antigo`
#'   (1985-2017) ou `rais_novo` (2018+) automaticamente.
#' @param table character ou NULL. Nome explícito da tabela:
#'   `"rais_antigo"`, `"rais_novo"` ou `"rais_estab"`.
#'   Tem prioridade sobre `year`.
#' @param type character ou NULL. `"vinculos"` (seleciona antigo+novo),
#'   `"estabelecimentos"` (seleciona `rais_estab`).
#'
#' @return objeto `tbl_dbi` (lazy frame do dplyr).
#'
#' @examples
#' # Small in-memory-style example with toy tables
#' db  <- tempfile(fileext = ".duckdb")
#' con <- rais_connect(db, quiet = TRUE)
#' DBI::dbWriteTable(con, "rais_novo",
#'                   data.frame(ano = 2022L, sigla_uf = c(23L, 24L)))
#' DBI::dbWriteTable(con, "rais_antigo",
#'                   data.frame(ano = 2015L, sigla_uf = 23L))
#'
#' rais_tbl(con, year = 2022)           # rais_novo
#' rais_tbl(con, year = 2015)           # rais_antigo
#' rais_tbl(con, table = "rais_novo")   # explicit table name
#'
#' DBI::dbDisconnect(con, shutdown = TRUE)
#' unlink(db)
#'
#' @seealso [rais_connect()], [rais_info()]
#' @export
rais_tbl <- function(con,
                     year  = NULL,
                     table = NULL,
                     type  = NULL) {

  # 1. Nome explícito tem prioridade
  if (!is.null(table)) {
    validas <- c("rais_antigo", "rais_novo", "rais_estab", "rais_domestico")
    if (!table %in% validas)
      cli::cli_abort(c(
        "x" = "Tabela {.val {table}} inv\u00e1lida.",
        "i" = "Use uma de: {.val {validas}}"
      ))
    if (!DBI::dbExistsTable(con, table))
      cli::cli_abort("Tabela {.val {table}} n\u00e3o encontrada no banco.")
    return(dplyr::tbl(con, table))
  }

  # 2. Por tipo
  if (!is.null(type)) {
    type <- match.arg(type, c("vinculos", "estabelecimentos"))
    if (type == "estabelecimentos") {
      if (!DBI::dbExistsTable(con, "rais_estab"))
        cli::cli_abort("Tabela {.val rais_estab} n\u00e3o encontrada. Use {.code rais_load(type = 'estabelecimentos')}.")
      return(dplyr::tbl(con, "rais_estab"))
    }
    # vinculos: combinar antigo + novo se ambos existirem
    has_antigo <- DBI::dbExistsTable(con, "rais_antigo")
    has_novo   <- DBI::dbExistsTable(con, "rais_novo")
    if (has_antigo && has_novo) {
      cli::cli_inform(c(
        "i" = "Retornando {.val rais_novo} (2018+). Para antigo use {.code rais_tbl(con, year = 2010)}."
      ))
      return(dplyr::tbl(con, "rais_novo"))
    }
    tbl_name <- if (has_novo) "rais_novo" else if (has_antigo) "rais_antigo" else
      cli::cli_abort("Nenhuma tabela de v\u00ednculos encontrada.")
    return(dplyr::tbl(con, tbl_name))
  }

  # 3. Por ano
  if (!is.null(year)) {
    year <- as.integer(year)
    tbl_name <- if (.is_rais_novo(year)) "rais_novo" else "rais_antigo"
    if (!DBI::dbExistsTable(con, tbl_name))
      cli::cli_abort(c(
        "x" = "Tabela {.val {tbl_name}} n\u00e3o encontrada.",
        "i" = "Carregue dados de {year} com {.code rais_load(years = {year})}."
      ))
    return(dplyr::tbl(con, tbl_name) |>
             dplyr::filter(ano == year))
  }

  # 4. Sem argumento: retorna rais_novo se existir, senão rais_antigo
  tabs <- DBI::dbListTables(con)
  rais_tabs <- intersect(tabs, c("rais_novo", "rais_antigo", "rais_estab"))
  if (length(rais_tabs) == 0L)
    cli::cli_abort("Nenhuma tabela RAIS encontrada. Use {.code rais_load()} primeiro.")

  preferred <- c("rais_novo", "rais_antigo", "rais_estab")
  tbl_name  <- preferred[preferred %in% rais_tabs][1L]
  cli::cli_inform("Usando tabela {.val {tbl_name}}. Especifique {.arg year}, {.arg table} ou {.arg type} para outra tabela.")
  dplyr::tbl(con, tbl_name)
}
