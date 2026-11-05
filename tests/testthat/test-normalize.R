test_that(".normalize_pipeline finds original names in dict", {
  dict <- datarais:::.DICT_VINCULOS

  # Caso central: nome original no dict \u2192 mapeado corretamente
  r1 <- datarais:::.normalize_pipeline("Faixa Hora Contrat", dict)
  expect_equal(as.character(r1), "faixa_horas_contratadas")

  r2 <- datarais:::.normalize_pipeline("Vl Remun M\u00e9dia Nom", dict)
  expect_equal(as.character(r2), "vl_remun_media_nom")

  r3 <- datarais:::.normalize_pipeline("CLAS CNAE 20", dict)
  expect_equal(as.character(r3), "cnae20_classe")
})

test_that(".normalize_pipeline handles case-insensitive lookup", {
  dict <- datarais:::.DICT_VINCULOS
  r <- datarais:::.normalize_pipeline("vl remun media nom", dict)
  # N\u00e3o est\u00e1 no dict mas ap\u00f3s snake_clean \u2192 "vl_remun_media_nom" \u2192 est\u00e1
  expect_equal(as.character(r), "vl_remun_media_nom")
})

test_that(".normalize_pipeline falls back to snake_clean for unknowns", {
  dict <- datarais:::.DICT_VINCULOS
  r <- datarais:::.normalize_pipeline("Coluna Totalmente Desconhecida", dict)
  expect_equal(as.character(r), "coluna_totalmente_desconhecida")
  expect_equal(attr(r, "unmapped"), "Coluna Totalmente Desconhecida")
})

test_that(".dedup_names adds suffix for duplicates", {
  r <- datarais:::.dedup_names(c("a", "b", "a", "a", "c"))
  expect_equal(r, c("a", "b", "a_2", "a_3", "c"))
})

test_that(".cast_col coerces to INTEGER correctly", {
  expect_equal(datarais:::.cast_col(c("23", "24"), "INTEGER"), c(23L, 24L))
  expect_equal(datarais:::.cast_col(c("2.500,50"), "DOUBLE"), 2500.5)
})

test_that("schema has correct types for key columns", {
  schema <- datarais:::.SCHEMA_VINCULOS
  expect_equal(schema[["vl_remun_media_nom"]], "DOUBLE")
  expect_equal(schema[["sexo"]], "INTEGER")
  expect_equal(schema[["id_municipio"]], "INTEGER")
  expect_equal(schema[["cnae20_subclasse"]], "VARCHAR")
  expect_equal(schema[["ano"]], "INTEGER")
})

test_that(".align_to_schema fills missing columns with typed NA", {
  df <- data.frame(ano = 2010L, sigla_uf = 23L, fonte_tipo = "vinculos_antigo")
  out <- datarais:::.align_to_schema(df, "rais_antigo")
  # raca_cor ausente em 2010 \u2192 deve virar NA_integer_
  expect_true("raca_cor" %in% names(out))
  expect_true(is.integer(out$raca_cor))
  expect_true(is.na(out$raca_cor))
})
