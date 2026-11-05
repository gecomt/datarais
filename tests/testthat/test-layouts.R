test_that(".layout_periodo returns correct period", {
  expect_equal(datarais:::.layout_periodo(1990), "v1985_1993")
  expect_equal(datarais:::.layout_periodo(2010), "v1994_2014")
  expect_equal(datarais:::.layout_periodo(2015), "v2015")
  expect_equal(datarais:::.layout_periodo(2018), "v2018_2019")
  expect_equal(datarais:::.layout_periodo(2022), "v2020_atual")
})

test_that(".encoding_para_ano returns correct encoding", {
  expect_equal(datarais:::.encoding_para_ano(2010), "latin1")
  expect_equal(datarais:::.encoding_para_ano(2020), "UTF-8")
})

test_that(".usa_ppmd detects PPMd years", {
  expect_true(datarais:::.usa_ppmd(2015))
  expect_true(datarais:::.usa_ppmd(2019))
  expect_false(datarais:::.usa_ppmd(2020))
})

test_that(".ufs_disponiveis excludes missing states", {
  ufs_85 <- datarais:::.ufs_disponiveis(1985)
  expect_false("TO" %in% ufs_85)
  expect_false("MA" %in% ufs_85)
  ufs_90 <- datarais:::.ufs_disponiveis(1990)
  expect_true("MA" %in% ufs_90)
})

test_that(".deve_ignorar correctly identifies special files", {
  expect_true(datarais:::.deve_ignorar("IGNORADOS1990.7z"))
  expect_true(datarais:::.deve_ignorar("Aviso.txt"))
  expect_false(datarais:::.deve_ignorar("CE2022.7z"))
  # Com incluir_ignorados = TRUE, n\u00e3o ignora
  expect_false(datarais:::.deve_ignorar("IGNORADOS1990.7z", incluir_ignorados = TRUE))
})

test_that(".nome_estab returns correct filename pattern", {
  expect_match(datarais:::.nome_estab(2003), "\\.zip$")
  expect_match(datarais:::.nome_estab(2008), "^Estb")
  expect_match(datarais:::.nome_estab(2015), "^ESTB")
  expect_equal(datarais:::.nome_estab(2022), "RAIS_ESTAB_PUB.7z")
})

test_that("rais_layouts returns data.frame", {
  expect_silent(df <- rais_layouts(verbose = FALSE))
  expect_s3_class(df, "data.frame")
  expect_true("periodo" %in% names(df))
})

test_that("rais_layouts prints a summary when verbose = TRUE", {
  expect_output(suppressMessages(rais_layouts(verbose = TRUE)), "periodo")
})
