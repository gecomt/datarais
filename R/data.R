#' Tabela de UFs brasileiras com códigos IBGE e regiões
#'
#' Data frame com as 27 unidades federativas, seus códigos numéricos do IBGE
#' e regiões geográficas. Útil para joins com os microdados da RAIS, que
#' armazenam o código numérico da UF.
#'
#' @format Data frame com 27 linhas e 3 colunas:
#' \describe{
#'   \item{sigla}{Sigla da UF (character). Ex: `"SP"`, `"CE"`, `"RN"`.}
#'   \item{codigo}{Código numérico IBGE (integer). Ex: `35`, `23`, `24`.}
#'   \item{regiao}{Região geográfica (character): `"Norte"`, `"Nordeste"`,
#'     `"Sudeste"`, `"Sul"` ou `"Centro-Oeste"`.}
#' }
#'
#' @source IBGE.
#'
#' @examples
#' data(uf_codigos)
#' head(uf_codigos)
#'
#' \donttest{
#' if (interactive()) {
#'   con <- rais_connect(file.path(tempdir(), "rais.duckdb"))
#'   if ("rais_novo" %in% DBI::dbListTables(con)) {
#'     df <- dplyr::tbl(con, "rais_novo") |> dplyr::collect()
#'     dplyr::left_join(df, uf_codigos, by = c("sigla_uf" = "sigla"))
#'   }
#'   DBI::dbDisconnect(con, shutdown = TRUE)
#' }
#' }
"uf_codigos"
