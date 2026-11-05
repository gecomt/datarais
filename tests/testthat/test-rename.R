test_that("rais_rename_cols renames known columns", {
  df <- data.frame(
    "Vl Remun M\u00e9dia Nom"   = 1:3,
    "Sexo Trabalhador"     = c(1,2,1),
    "UF"                   = c(23,24,25),
    check.names            = FALSE
  )
  out <- rais_rename_cols(df, quiet = TRUE)
  expect_true("vl_remun_media_nom" %in% names(out))
  expect_true("sexo"               %in% names(out))
  expect_true("sigla_uf"           %in% names(out))
})

test_that("rais_col_dictionary returns data.frame", {
  d <- rais_col_dictionary()
  expect_s3_class(d, "data.frame")
  expect_true(all(c("original", "normalizado") %in% names(d)))
})

test_that("rais_translate_cols translates correctly", {
  res <- rais_translate_cols(c("Vl Remun M\u00e9dia Nom", "UF", "DESCONHECIDA"))
  expect_equal(res[1], "vl_remun_media_nom")
  expect_equal(res[2], "sigla_uf")
  expect_equal(res[3], "DESCONHECIDA")  # mant\u00e9m original
})

# ── rais_col_info ─────────────────────────────────────────────────────────────

test_that("rais_col_info returns tibble with expected columns", {
  res <- rais_col_info()
  expect_s3_class(res, "data.frame")
  expect_true(all(c("coluna", "descricao", "tipo_r", "tipo_sql",
                     "disponivel_desde") %in% names(res)))
  expect_gt(nrow(res), 0L)
})

test_that("rais_col_info filters by column name", {
  res <- rais_col_info("vl_remun_media_nom")
  expect_equal(nrow(res), 1L)
  expect_equal(res$coluna, "vl_remun_media_nom")
})

test_that("rais_col_info search works case-insensitively", {
  res <- rais_col_info(search = "remun")
  expect_gt(nrow(res), 0L)
  expect_true(all(grepl("remun", res$coluna, ignore.case = TRUE) |
                  grepl("remun", res$descricao, ignore.case = TRUE)))
})

test_that("rais_col_info warns on unknown column", {
  expect_warning(
    rais_col_info("coluna_inexistente"),
    regexp = "n.o encontrada"
  )
})
