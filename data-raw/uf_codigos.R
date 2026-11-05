## Script para gerar o dataset uf_codigos
## Execute com: source("data-raw/uf_codigos.R")

uf_codigos <- data.frame(
  sigla  = c("RO","AC","AM","RR","PA","AP","TO",
              "MA","PI","CE","RN","PB","PE","AL","SE","BA",
              "MG","ES","RJ","SP",
              "PR","SC","RS",
              "MS","MT","GO","DF"),
  codigo = c(11L,12L,13L,14L,15L,16L,17L,
              21L,22L,23L,24L,25L,26L,27L,28L,29L,
              31L,32L,33L,35L,
              41L,42L,43L,
              50L,51L,52L,53L),
  regiao = c(rep("Norte",    7L),
              rep("Nordeste", 9L),
              rep("Sudeste",  4L),
              rep("Sul",      3L),
              rep("Centro-Oeste", 4L)),
  stringsAsFactors = FALSE
)

usethis::use_data(uf_codigos, overwrite = TRUE)
