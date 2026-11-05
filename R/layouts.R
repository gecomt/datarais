# layouts.R
# Defini\u00e7\u00e3o dos per\u00edodos de layout da RAIS e regras de parsing por per\u00edodo
#
# A RAIS teve m\u00faltiplos formatos ao longo dos anos.
# Este m\u00f3dulo centraliza essas diferen\u00e7as para que o parser
# aplique as regras corretas para cada ano.

# -- Per\u00edodos de layout --------------------------------------------------------

#' Retorna o período de layout correto para um ano
#'
#' Períodos identificados nos layouts oficiais do MTE:
#'
#' | Período | Arquivo de layout |
#' |---|---|
#' | 1985–1993 | RAIS_vinculos_layout1985a1993.xls |
#' | 1994–2014 | RAIS_vinculos_layout.xls (geral) |
#' | 2015      | RAIS_vinculos_layout2015.xls |
#' | 2016      | RAIS_vinculos_layout2016.xls |
#' | 2017      | RAIS_vinculos_layout2017.xls |
#' | 2018–2019 | RAIS_vinculos_layout2018e2019.xls |
#' | 2020+     | RAIS_vinculos_layout2020.xls |
#'
#' @noRd
.layout_periodo <- function(year) {
  year <- as.integer(year)
  if      (year <= 1993L) "v1985_1993"
  else if (year <= 2014L) "v1994_2014"
  else if (year == 2015L) "v2015"
  else if (year == 2016L) "v2016"
  else if (year == 2017L) "v2017"
  else if (year <= 2019L) "v2018_2019"
  else                    "v2020_atual"
}

# -- Encoding por per\u00edodo ------------------------------------------------------

#' Encoding correto para cada período
#' @noRd
.encoding_para_ano <- function(year) {
  if (year >= 2018L) "UTF-8" else "latin1"
}

# -- Compress\u00e3o por per\u00edodo ----------------------------------------------------

#' Informa se o ano usa PPMd (requer 7-Zip externo)
#'
#' O CAGED/RAIS antigo (até 2019) usa compressão PPMd do 7-Zip,
#' que não é suportada pela libarchive. A partir de 2020 usa LZMA,
#' compatível com archive::archive_extract().
#' @noRd
.usa_ppmd <- function(year) year < 2020L

# -- Colunas num\u00e9ricas por per\u00edodo ---------------------------------------------

#' Colunas que devem ser numéricas para cada período de layout
#'
#' Inclui todos os nomes possíveis (antes e depois da normalização)
#' para garantir coerção correta mesmo antes do rename.
#' @noRd
.cols_numericas_periodo <- function(periodo) {
  # N\u00facleo comum a todos os per\u00edodos
  comum <- c(
    # Geo
    "municipio", "id_municipio", "uf", "sigla_uf",
    # V\u00ednculo
    "vinculo_ativo_3112", "tipo_vinculo", "tipo_admissao",
    "mes_admissao", "motivo_desligamento", "mes_desligamento",
    "tempo_emprego", "tipo_salario",
    # Trabalhador
    "sexo", "idade",
    "grau_instrucao", "grau_instrucao_apos_2005",
    "ind_portador_defic",
    # Sal\u00e1rio
    "vl_remun_media_nom", "vl_remun_media_sm",
    "vl_remun_dezembro_nom", "vl_remun_dezembro_sm",
    "vl_salario_contratual", "vl_ultima_remun_ano",
    # Horas
    "qtd_horas_contratadas",
    # Afastamentos
    "causa_afastamento_1", "causa_afastamento_2", "causa_afastamento_3",
    "qtd_dias_afastamento",
    # Estabelecimento
    "tamanho_estabelecimento", "tipo_estabelecimento",
    "natureza_juridica", "ind_simples", "ind_cei_vinculado"
  )

  periodo_especifico <- switch(periodo,

    "v1985_1993" = c(
      # Layout mais antigo: sem raca_cor, sem ind_portador_defic,
      # sem cbo_2002 (usa cbo_94), sem cnae20
      "cbo_94", "cnae95_classe",
      "ibge_subsetor", "subsetor", "subatividade",
      "saldo_mov", "admitidos_desligados",
      "ind_aprendiz", "indicadoraprendiz"
    ),

    "v1994_2014" = c(
      # Inclui raca_cor a partir de ~1999 (toleramos pr\u00e9-1999 como NA)
      "raca_cor",
      "cbo_94",       # CBO 94 ainda presente
      "cbo_2002",     # CBO 2002 introduzido em 2003
      "cnae95_classe",
      "cnae20_classe", "cnae20_subclasse",  # cnae20 a partir de 2006
      "ind_portador_defic", "tipo_deficiencia",
      "saldo_mov", "saldomovimentacao"
    ),

    "v2015" = ,
    "v2016" = ,
    "v2017" = c(
      "raca_cor",
      "cbo_2002",
      "cnae20_classe", "cnae20_subclasse",
      "ind_portador_defic", "tipo_deficiencia",
      "faixa_etaria", "faixa_tempo_emprego",
      "faixa_remun_media_sm", "faixa_remun_dezembro_sm",
      "faixa_horas_contratadas"
    ),

    "v2018_2019" = c(
      "raca_cor",
      "cbo_2002",
      "cnae20_classe", "cnae20_subclasse",
      "ind_portador_defic", "tipo_deficiencia",
      "faixa_etaria", "faixa_tempo_emprego",
      "faixa_remun_media_sm", "faixa_remun_dezembro_sm"
    ),

    "v2020_atual" = c(
      "raca_cor",
      "cbo_2002",
      "cnae20_classe", "cnae20_subclasse",
      "ind_portador_defic", "tipo_deficiencia",
      "faixa_etaria", "faixa_tempo_emprego",
      "faixa_remun_media_sm", "faixa_remun_dezembro_sm",
      "ind_trab_intermitente", "ind_trab_parcial"
    ),

    character(0L)
  )

  unique(c(comum, periodo_especifico))
}

# -- Tratamento de arquivos especiais ------------------------------------------

#' Detecta se um arquivo deve ser ignorado (IGNORADOS, Aviso, etc.)
#'
#' Alguns anos têm arquivos auxiliares que não são microdados:
#' - `IGNORADOS*.7z` / `IGNORANDOS*.7z` — registros sem UF identificada
#' - `Aviso.txt` — notas metodológicas (1985, 1986)
#'
#' @param path character. Caminho do arquivo.
#' @param incluir_ignorados logical. Incluir registros não identificados?
#'   Default: `FALSE`.
#' @return logical. `TRUE` se o arquivo deve ser pulado.
#' @noRd
.deve_ignorar <- function(path, incluir_ignorados = FALSE) {
  nome <- toupper(basename(path))
  if (grepl("^AVISO",  nome)) return(TRUE)
  if (grepl("^LEIA",   nome, ignore.case = TRUE)) return(TRUE)  # Leia-me.txt (2019)
  if (grepl("\\.(htm|html)$|\\.htm ", nome, ignore.case = TRUE)) return(TRUE)  # arquivos .htm
  if (grepl("IGNORA",  nome) && !incluir_ignorados) return(TRUE)
  FALSE
}

#' Detecta se um arquivo é da pasta Legado (layout anterior do mesmo ano)
#' @noRd
.e_legado <- function(path) {
  grepl("/[Ll]egado/", path, fixed = FALSE)
}

# -- Regras de nomenclatura de arquivos ----------------------------------------

#' Retorna o padrão de nome de arquivo de estabelecimentos para um ano
#' @noRd
.nome_estab <- function(year) {
  year <- as.integer(year)
  if      (year %in% 2002L:2006L) glue::glue("Estb{year}.zip")
  else if (year %in% c(2008L, 2012L)) glue::glue("Estb{year}.7z")
  else if (year >= 2018L)          "RAIS_ESTAB_PUB.7z"
  else                             glue::glue("ESTB{year}.7z")
}

#' UFs disponíveis para um dado ano (alguns estados entraram depois)
#' @noRd
.ufs_disponiveis <- function(year) {
  year <- as.integer(year)
  ufs  <- names(.UF_CODIGOS)

  # 1985: sem TO e sem MA (n\u00e3o declararam naquele ano)
  if (year == 1985L) ufs <- setdiff(ufs, c("TO", "MA"))

  # 1986: sem PA e sem TO
  if (year == 1986L) ufs <- setdiff(ufs, c("PA", "TO"))

  # TO criado em 1988 como estado; dados RAIS aparecem a partir de 1989
  if (year < 1989L)  ufs <- setdiff(ufs, "TO")

  ufs
}

# -- Fun\u00e7\u00e3o principal de contexto de parsing -----------------------------------

#' Retorna o contexto completo de parsing para um dado ano
#'
#' Centraliza todas as decisões de layout em uma única chamada,
#' usada internamente por `.read_rais_txt()`.
#'
#' @param year integer. Ano dos dados.
#' @return lista com campos: `periodo`, `encoding`, `usa_ppmd`,
#'   `cols_numericas`, `ufs_disponiveis`.
#' @noRd
.contexto_parsing <- function(year) {
  year    <- as.integer(year)
  periodo <- .layout_periodo(year)
  list(
    ano             = year,
    periodo         = periodo,
    encoding        = .encoding_para_ano(year),
    usa_ppmd        = .usa_ppmd(year),
    cols_numericas  = .cols_numericas_periodo(periodo),
    ufs_disponiveis = .ufs_disponiveis(year),
    nome_estab      = .nome_estab(year)
  )
}

# -- Documenta\u00e7\u00e3o das diferen\u00e7as de layout para o usu\u00e1rio ---------------------

#' Exibe um resumo dos layouts da RAIS por período
#'
#' Mostra as diferenças de layout, encoding, compressão e variáveis
#' entre os diferentes períodos da RAIS.
#'
#' @param verbose logical. Imprime o resumo no console. Default: `TRUE`.
#' @return invisível: data.frame com o resumo.
#' @examples
#' rais_layouts()
#' @export
rais_layouts <- function(verbose = TRUE) {
  df <- data.frame(
    periodo       = c("1985\u20131993", "1994\u20132014", "2015", "2016",
                      "2017", "2018\u20132019", "2020+"),
    layout_id     = c("v1985_1993","v1994_2014","v2015","v2016",
                      "v2017","v2018_2019","v2020_atual"),
    fonte         = c("Por UF","Por UF","Por UF","Por UF",
                      "Por UF","Por Regi\u00e3o","Por Regi\u00e3o"),
    encoding      = c("latin1","latin1","latin1","latin1",
                      "latin1","UTF-8","UTF-8"),
    compressao    = c("PPMd*","PPMd*","PPMd*","PPMd*",
                      "PPMd*","PPMd*","LZMA"),
    raca_cor      = c("n\u00e3o","sim (1999+)","sim","sim","sim","sim","sim"),
    cbo_2002      = c("n\u00e3o","sim (2003+)","sim","sim","sim","sim","sim"),
    cnae_20       = c("n\u00e3o","sim (2006+)","sim","sim","sim","sim","sim"),
    trab_intermit = c("n\u00e3o","n\u00e3o","n\u00e3o","n\u00e3o","n\u00e3o","n\u00e3o","sim"),
    stringsAsFactors = FALSE
  )

  if (verbose) {
    cli::cli_h1(.tr("Layouts da RAIS por per\u00edodo"))
    cli::cli_inform(c(
      "i" = "(*) PPMd requer 7-Zip instalado: {.url https://www.7-zip.org}",
      "i" = "    archive::archive_extract() funciona apenas para LZMA (2020+)"
    ))
    cli::cli_h2(.tr("V\u00ednculos"))
    print(df[, c("periodo","fonte","encoding","compressao",
                 "raca_cor","cbo_2002","cnae_20","trab_intermit")])

    cli::cli_h2(.tr("Estabelecimentos"))
    estab <- data.frame(
      periodo    = c("1985\u20132001","2002\u20132006","2007\u20132011",
                     "2012","2013\u20132017","2018\u20132019","2020+"),
      arquivo    = c("ESTB{ano}.7z","Estb{ano}.zip","ESTB{ano}.7z",
                     "Estb2012.7z","ESTB{ano}.7z",
                     "RAIS_ESTAB_PUB.7z","RAIS_ESTAB_PUB.7z"),
      stringsAsFactors = FALSE
    )
    print(estab)
  }

  invisible(df)
}
