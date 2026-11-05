test_that("rais_set_language accepts en and pt", {
  old <- getOption("datarais.language")
  on.exit(options(datarais.language = old), add = TRUE)
  rais_set_language("en")
  expect_equal(getOption("datarais.language"), "en")
  rais_set_language("pt")
  expect_equal(getOption("datarais.language"), "pt")
  rais_set_language(NULL)
  expect_null(getOption("datarais.language"))
})

test_that("rais_language returns en or pt", {
  lang <- rais_language()
  expect_true(lang %in% c("en", "pt"))
})

test_that(".tr() returns character", {
  res <- datarais:::.tr("Done!")
  expect_type(res, "character")
  expect_true(nchar(res) > 0)
})
