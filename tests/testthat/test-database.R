test_that("rais_connect creates/opens a duckdb file", {
  db <- file.path(tempdir(), "test_rais.duckdb")
  on.exit(unlink(db))
  con <- rais_connect(db, quiet = TRUE)
  expect_s4_class(con, "duckdb_connection")
  DBI::dbDisconnect(con, shutdown = TRUE)
})

test_that("rais_to_duckdb rejects empty data.frame", {
  db <- file.path(tempdir(), "test_rais2.duckdb")
  on.exit(unlink(db))
  n <- rais_to_duckdb(data.frame(), db_path = db)
  expect_equal(n, 0L)
})

test_that("rais_info reports empty db gracefully", {
  db  <- file.path(tempdir(), "test_empty.duckdb")
  con <- rais_connect(db, quiet = TRUE)
  DBI::dbDisconnect(con, shutdown = TRUE)
  on.exit(unlink(db))
  res <- rais_info(db)
  expect_true(is.null(res) || nrow(res) == 0)
})

# ── rais_tbl ──────────────────────────────────────────────────────────────────

test_that("rais_tbl returns tbl_dbi on existing table", {
  db  <- file.path(tempdir(), "test_tbl.duckdb")
  on.exit(unlink(db))
  con <- rais_connect(db, quiet = TRUE)
  DBI::dbExecute(con, "CREATE TABLE rais_novo (ano INTEGER, sigla_uf INTEGER)")
  res <- rais_tbl(con, table = "rais_novo")
  expect_s3_class(res, "tbl")
  DBI::dbDisconnect(con, shutdown = TRUE)
})

test_that("rais_tbl errors on invalid table name", {
  db  <- file.path(tempdir(), "test_tbl2.duckdb")
  on.exit(unlink(db))
  con <- rais_connect(db, quiet = TRUE)
  expect_error(rais_tbl(con, table = "tabela_invalida"), class = "error")
  DBI::dbDisconnect(con, shutdown = TRUE)
})

test_that("rais_tbl errors when no RAIS tables exist", {
  db  <- file.path(tempdir(), "test_tbl3.duckdb")
  on.exit(unlink(db))
  con <- rais_connect(db, quiet = TRUE)
  expect_error(rais_tbl(con), class = "error")
  DBI::dbDisconnect(con, shutdown = TRUE)
})
