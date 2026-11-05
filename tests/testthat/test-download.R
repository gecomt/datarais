
# ── rais_download: testes offline ────────────────────────────────────────────

test_that("rais_download validates years argument", {
  expect_error(rais_download(years = 1800), class = "error")
  expect_error(rais_download(years = NA_integer_), class = "error")
  expect_error(rais_download(years = "2022"), class = "error")
})

test_that("rais_download validates type argument", {
  expect_error(
    rais_download(years = 2022, type = "invalido"),
    class = "error"
  )
})

test_that("rais_download validates state argument", {
  expect_error(
    rais_download(years = 2010, state = "XX"),
    class = "error"
  )
})

test_that("rais_download returns 0 rows with no files (offline/empty HF)", {
  skip_on_cran()
  skip_if_offline()
  result <- suppressMessages(suppressWarnings(rais_download(
    years   = 2022,
    type    = "vinculos",
    destdir = tempdir(),
    workers = 1L,
    timeout = 5L
  )))
  expect_s3_class(result, "data.frame")
  expect_true(all(c("arquivo", "status") %in% names(result)))
})

# ── rais_download_layouts ─────────────────────────────────────────────────────

test_that("rais_download_layouts validates type argument", {
  expect_error(
    rais_download_layouts(type = "invalido"),
    class = "error"
  )
})

test_that("rais_download_layouts returns tibble (offline/empty HF)", {
  skip_on_cran()
  skip_if_offline()
  result <- suppressWarnings(
    rais_download_layouts(
      type    = "vinculos",
      destdir = tempdir(),
      timeout = 5L,
      verbose = FALSE
    )
  )
  expect_s3_class(result, "data.frame")
})

# ── Download tasks: every file pattern of the repository ─────────────────────

test_that(".build_tasks_rais covers the old layout (one file per state)", {
  t <- datarais:::.build_tasks_rais(2010, "vinculos", NULL, FALSE)
  expect_equal(nrow(t), 27L)
  expect_true(all(t$type == "vinculos_antigo"))
  expect_true("RN2010.7z" %in% t$nome_arquivo)

  t_rn <- datarais:::.build_tasks_rais(2010, "vinculos", "RN", FALSE)
  expect_equal(t_rn$nome_arquivo, "RN2010.7z")
})

test_that(".build_tasks_rais covers the new layout (regions, NI from 2022)", {
  regioes <- c("CENTRO_OESTE", "MG_ES_RJ", "NORDESTE", "NORTE", "SP", "SUL")

  t19 <- datarais:::.build_tasks_rais(2019, "vinculos", NULL, FALSE)
  expect_setequal(t19$scope, regioes)
  expect_true(all(t19$type == "vinculos_novo"))

  t22 <- datarais:::.build_tasks_rais(2022, "vinculos", NULL, FALSE)
  expect_setequal(t22$scope, c(regioes, "NI"))
  expect_true("RAIS_VINC_PUB_NI.7z" %in% t22$nome_arquivo)

  # state is ignored in the new layout: whole regions are downloaded
  t_rn <- datarais:::.build_tasks_rais(2022, "vinculos", "RN", FALSE)
  expect_equal(nrow(t_rn), nrow(t22))
})

test_that(".build_tasks_rais uses the real establishment file names", {
  est <- function(y) {
    datarais:::.build_tasks_rais(y, "estabelecimentos", NULL, FALSE)$nome_arquivo
  }
  expect_equal(est(1995), "ESTB1995.7z")
  expect_equal(est(2004), "Estb2004.zip")
  expect_equal(est(2008), "Estb2008.7z")
  expect_equal(est(2012), "Estb2012.7z")
  expect_equal(est(2017), "ESTB2017.7z")
  expect_equal(est(2022), "RAIS_ESTAB_PUB.7z")
})

test_that(".build_tasks_rais combines employment records and establishments", {
  t <- datarais:::.build_tasks_rais(2022, "all", NULL, FALSE)
  expect_equal(nrow(t), 8L)
  expect_equal(sum(t$type == "estab"), 1L)

  t2 <- datarais:::.build_tasks_rais(2022, "vinculos", NULL, include_estab = TRUE)
  expect_equal(nrow(t2), 8L)
})

test_that("download URLs point to the HuggingFace dataset", {
  t <- datarais:::.build_tasks_rais(2022, "estabelecimentos", NULL, FALSE)
  expect_match(
    t$url,
    "^https://huggingface.co/datasets/alexsandroprado/rais/resolve/main/RAIS/2022/RAIS_ESTAB_PUB.7z$"
  )
})
