test_that("rais_available returns tibble", {
  skip_on_cran()
  skip_if_offline()
  res <- rais_available(verbose = FALSE)
  skip_if(nrow(res) == 0, "HuggingFace repository not yet populated")
  expect_s3_class(res, "data.frame")
  expect_true(all(c("ano", "layout", "url_base") %in% names(res)))
  expect_true(nrow(res) > 0)
})

test_that("rais_available_years returns integers", {
  skip_on_cran()
  skip_if_offline()
  anos <- rais_available_years()
  skip_if(is.null(anos) || length(anos) == 0, "HuggingFace repository not yet populated")
  expect_type(anos, "integer")
  expect_true(all(anos >= 1985))
})

test_that("rais_hf_files returns tibble with expected columns", {
  skip_on_cran()
  skip_if_offline()
  res <- rais_hf_files(
    years   = as.integer(format(Sys.Date(), "%Y")) - 1L,
    verbose = FALSE
  )
  skip_if(nrow(res) == 0, "HuggingFace repository not yet populated")
  expect_s3_class(res, "data.frame")
  expect_true(all(c("ano", "arquivo", "tipo", "layout",
                     "tamanho_mb", "url") %in% names(res)))
  expect_type(res$ano, "integer")
  expect_type(res$tamanho_mb, "double")
  expect_true(all(grepl("^https://", res$url)))
})
