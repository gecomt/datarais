test_that("rais_status returns list with expected fields", {
  skip_on_cran()
  skip_if_offline()
  res <- rais_status(verbose = FALSE)
  expect_type(res, "list")
  expect_true(all(c("online", "latencia_ms", "url", "mensagem") %in% names(res)))
  expect_type(res$online, "logical")
})
