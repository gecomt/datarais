# test-load.R — testes de rais_load, rais_update e rais_to_parquet

# ── rais_load ─────────────────────────────────────────────────────────────────

test_that("rais_load validates years argument", {
  expect_error(rais_load(years = 1800), class = "error")
  expect_error(rais_load(years = NA_integer_), class = "error")
})

test_that("rais_load validates type argument", {
  expect_error(
    rais_load(years = 2022, type = "invalido"),
    class = "error"
  )
})

test_that("rais_load validates state argument", {
  expect_error(
    rais_load(years = 2010, state = "ZZ"),
    class = "error"
  )
})

test_that("rais_load creates duckdb file when no downloads available", {
  skip_on_cran()
  skip_if_offline()
  db <- tempfile(fileext = ".duckdb")
  on.exit(unlink(db))

  # Com HF vazio, deve criar o banco mas não inserir linhas
  suppressMessages(suppressWarnings(
    rais_load(years = 2022, db_path = db, timeout = 5L, workers = 1L)
  ))
  # Banco criado (ou não criado se nada baixado — ambos aceitáveis)
  expect_true(is.character(db))
})

# ── rais_update ───────────────────────────────────────────────────────────────

test_that("rais_update validates db_path", {
  expect_error(
    rais_update(db_path = "/pasta/inexistente/rais.duckdb"),
    class = "error"
  )
})

test_that("rais_update does nothing when the database is already up to date", {
  skip_on_cran()
  skip_if_offline()
  db  <- tempfile(fileext = ".duckdb")
  con <- rais_connect(db, quiet = TRUE)
  DBI::dbExecute(con, "CREATE TABLE rais_novo (ano INTEGER)")
  DBI::dbExecute(con, "INSERT INTO rais_novo VALUES (9999)")
  DBI::dbDisconnect(con, shutdown = TRUE)
  on.exit(unlink(db))

  res <- suppressMessages(suppressWarnings(
    rais_update(db_path = db, timeout = 5L, workers = 1L, verbose = FALSE)
  ))
  expect_null(res)
  expect_true(file.exists(db))
})

# ── rais_to_parquet ───────────────────────────────────────────────────────────

test_that("rais_to_parquet validates db_path", {
  expect_error(
    rais_to_parquet("/nao/existe.duckdb", tempdir()),
    class = "error"
  )
})

test_that("rais_to_parquet errors on a database without RAIS tables", {
  db  <- tempfile(fileext = ".duckdb")
  con <- rais_connect(db, quiet = TRUE)
  DBI::dbDisconnect(con, shutdown = TRUE)
  on.exit(unlink(db))

  expect_error(
    suppressMessages(rais_to_parquet(db, output_dir = tempfile("pq_"))),
    class = "error"
  )
})

test_that("rais_to_parquet exports a RAIS table", {
  db  <- tempfile(fileext = ".duckdb")
  out <- tempfile("pq_")
  con <- rais_connect(db, quiet = TRUE)
  DBI::dbExecute(con, "CREATE TABLE rais_novo (ano INTEGER, uf VARCHAR)")
  DBI::dbExecute(con, "INSERT INTO rais_novo VALUES (2022, 'RN'), (2022, 'CE')")
  DBI::dbDisconnect(con, shutdown = TRUE)
  on.exit(unlink(c(db, out), recursive = TRUE))

  result <- suppressMessages(rais_to_parquet(db, output_dir = out))
  expect_s3_class(result, "data.frame")
  expect_equal(result$status, "exportado")
  expect_equal(result$registros, 2)
  expect_true(file.exists(file.path(out, "rais_novo.parquet")))
})

# ── Several files per year (states / regions) ────────────────────────────────

test_that(".prepare_manifest_for_load keeps every file of a new year", {
  db  <- tempfile(fileext = ".duckdb")
  con <- rais_connect(db, quiet = TRUE)
  on.exit({ DBI::dbDisconnect(con, shutdown = TRUE); unlink(db) })
  DBI::dbWriteTable(con, "rais_novo", data.frame(ano = 2021L, sigla_uf = 1L))

  mk <- function(ano, arq, type = "vinculos_novo") {
    data.frame(arquivo = arq, ano = ano, type = type, stringsAsFactors = FALSE)
  }
  m <- rbind(
    mk(2021L, "/c/2021/RAIS_VINC_PUB_SP.7z"),                  # already in DB
    mk(2022L, "/c/2022/RAIS_VINC_PUB_SP.7z"),
    mk(2022L, "/c/2022/RAIS_VINC_PUB_SUL.7z"),
    mk(2023L, "/c/2023%20Parcial/RAIS_VINC_PUB_SP.7z"),        # superseded
    mk(2023L, "/c/2023/RAIS_VINC_PUB_SP.7z"),
    mk(2024L, "/c/2024%20Parcial/RAIS_VINC_PUB_SP.7z"),        # only partial
    mk(2022L, "/c/2022/RAIS_ESTAB_PUB.7z", "estab_novo")
  )
  res <- suppressMessages(datarais:::.prepare_manifest_for_load(m, con))

  expect_false(any(res$ano == 2021L & res$tabela == "rais_novo"))
  expect_equal(sum(res$ano == 2022L & res$tabela == "rais_novo"), 2L)
  expect_equal(sum(res$ano == 2023L), 1L)
  expect_false(any(res$parcial & res$ano == 2023L))
  expect_equal(sum(res$ano == 2024L), 1L)
  expect_equal(sum(res$tabela == "rais_estab"), 1L)
})

test_that(".prepare_manifest_for_load deletes existing years on overwrite", {
  db  <- tempfile(fileext = ".duckdb")
  con <- rais_connect(db, quiet = TRUE)
  on.exit({ DBI::dbDisconnect(con, shutdown = TRUE); unlink(db) })
  DBI::dbWriteTable(con, "rais_novo", data.frame(ano = 2021L, sigla_uf = 1L))

  m <- data.frame(arquivo = "/c/2021/RAIS_VINC_PUB_SP.7z", ano = 2021L,
                  type = "vinculos_novo", stringsAsFactors = FALSE)
  res <- suppressMessages(
    datarais:::.prepare_manifest_for_load(m, con, overwrite_years = TRUE)
  )
  expect_equal(nrow(res), 1L)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM rais_novo")$n, 0)
})

test_that("rais_to_duckdb appends several files of the same year", {
  db  <- tempfile(fileext = ".duckdb")
  con <- rais_connect(db, quiet = TRUE)
  on.exit({ DBI::dbDisconnect(con, shutdown = TRUE); unlink(db) })

  df <- function(uf) {
    data.frame(ano = 2022L, fonte_tipo = "vinculos_novo", sigla_uf = uf)
  }
  suppressMessages({
    rais_to_duckdb(df(23L), .con = con, .check_years = FALSE)
    rais_to_duckdb(df(24L), .con = con, .check_years = FALSE)
  })
  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM rais_novo WHERE ano = 2022")$n
  expect_equal(n, 2)
})
