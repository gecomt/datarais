# test-parse.R — testes de rais_parse e rais_parse_batch

test_that("rais_parse rejects non-existent file", {
  expect_error(
    rais_parse("/caminho/inexistente/arquivo.7z"),
    class = "error"
  )
})

test_that("rais_parse rejects unsupported extension", {
  tmp <- tempfile(fileext = ".csv")
  writeLines("col1,col2\n1,2", tmp)
  on.exit(unlink(tmp))
  expect_error(rais_parse(tmp), class = "error")
})

test_that("rais_parse_batch validates input", {
  # Lista vazia retorna NULL invisível
  result <- rais_parse_batch(character(0))
  expect_true(is.null(result))
})

test_that("rais_parse_batch validates paths", {
  # Arquivo inexistente → erro
  expect_error(
    rais_parse_batch("/nao/existe.7z"),
    class = "error"
  )
})
