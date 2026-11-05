# rename.R \u2014 Normaliza\u00e7\u00e3o de nomes de colunas da RAIS
# Mapeia todos os nomes hist\u00f3ricos \u2192 snake_case PT oficial

.DICT_VINCULOS <- c(
  # Geo
  "Munic\u00edpio"="id_municipio","Municipio"="id_municipio","MUN TRAB"="id_municipio",
  "municipio"="id_municipio","id_municipio"="id_municipio",
  "UF"="sigla_uf","uf"="sigla_uf","Uf"="sigla_uf","sigla_uf"="sigla_uf",
  # V\u00ednculo
  "V\u00ednculo Ativo 31/12"="vinculo_ativo_3112","Vinculo Ativo 31/12"="vinculo_ativo_3112",
  "EMP EM 31/12"="vinculo_ativo_3112","vinculo_ativo_3112"="vinculo_ativo_3112",
  "Tipo V\u00ednculo"="tipo_vinculo","Tipo Vinculo"="tipo_vinculo","TIPO VINCULO"="tipo_vinculo","tipo_vinculo"="tipo_vinculo",
  "Tipo Admiss\u00e3o"="tipo_admissao","Tipo Admissao"="tipo_admissao","tipo_admissao"="tipo_admissao",
  "M\u00eas Admiss\u00e3o"="mes_admissao","Mes Admissao"="mes_admissao","mes_admissao"="mes_admissao",
  "Data Admiss\u00e3o Declarada"="data_admissao","Data Admissao Declarada"="data_admissao","data_admissao_declarada"="data_admissao",
  "Motivo Desligamento"="motivo_desligamento","MOTIVO DESLIGAMENTO"="motivo_desligamento","motivo_desligamento"="motivo_desligamento",
  "M\u00eas Desligamento"="mes_desligamento","Mes Desligamento"="mes_desligamento","mes_desligamento"="mes_desligamento",
  "Tempo Emprego"="tempo_emprego","TEMPO EMPREGO"="tempo_emprego","tempo_emprego"="tempo_emprego",
  "Faixa Tempo Emprego"="faixa_tempo_emprego","Faixa Tempo de Emprego"="faixa_tempo_emprego","faixa_tempo_emprego"="faixa_tempo_emprego",
  # Trabalhador
  "Sexo Trabalhador"="sexo","SEXO TRABALHADOR"="sexo","sexo_trabalhador"="sexo","sexo"="sexo",
  "Ra\u00e7a Cor"="raca_cor","Raca Cor"="raca_cor","RACA COR"="raca_cor","raca_cor"="raca_cor",
  "Idade"="idade","IDADE"="idade","idade"="idade",
  "Faixa Et\u00e1ria"="faixa_etaria","Faixa Etaria"="faixa_etaria","faixa_etaria"="faixa_etaria",
  "Nacionalidade"="nacionalidade","NACIONALIDAD"="nacionalidade","nacionalidade"="nacionalidade",
  "Ind Portador Defic"="ind_portador_defic","IND PORTADOR DEFIC"="ind_portador_defic","ind_portador_defic"="ind_portador_defic",
  "Tipo Defic"="tipo_deficiencia","TIPO DEFIC"="tipo_deficiencia","tipo_defic"="tipo_deficiencia","tipo_deficiencia"="tipo_deficiencia",
  # Instru\u00e7\u00e3o
  "Escolaridade ap\u00f3s 2005"="grau_instrucao","Escolaridade apos 2005"="grau_instrucao",
  "Grau Instru\u00e7\u00e3o"="grau_instrucao","Grau Instrucao"="grau_instrucao","GRAU INSTRUCAO"="grau_instrucao",
  "grau_instrucao_apos_2005"="grau_instrucao","grau_instrucao"="grau_instrucao",
  # Ocupa\u00e7\u00e3o / CNAE
  "CBO Ocupa\u00e7\u00e3o 2002"="cbo_2002","CBO Ocupacao 2002"="cbo_2002","CBO OCUPACAO 2002"="cbo_2002","cbo_ocupacao_2002"="cbo_2002","cbo_2002"="cbo_2002",
  "CBO Ocupa\u00e7\u00e3o 94"="cbo_94","CBO Ocupacao 94"="cbo_94","cbo_94"="cbo_94",
  "CNAE 2.0 Classe"="cnae20_classe","CNAE 2.0"="cnae20_classe","CLAS CNAE 20"="cnae20_classe","cnae20_classe"="cnae20_classe",
  "CNAE 2.0 Subclasse"="cnae20_subclasse","CNAE 2.0 Sub Cl"="cnae20_subclasse","cnae20_subclasse"="cnae20_subclasse",
  "Classe CNAE 95"="cnae95_classe","CLAS CNAE 95"="cnae95_classe","cnae95_classe"="cnae95_classe",
  # Estabelecimento
  "Tamanho Estabelecimento"="tamanho_estabelecimento","TAMANHO ESTABELECIMENTO"="tamanho_estabelecimento","tamanho_estabelecimento"="tamanho_estabelecimento",
  "Tipo Estab"="tipo_estabelecimento","TIPO ESTAB"="tipo_estabelecimento","tipo_estab"="tipo_estabelecimento","tipo_estabelecimento"="tipo_estabelecimento",
  "Natureza Jur\u00eddica"="natureza_juridica","Natureza Juridica"="natureza_juridica","NAT JURIDICA"="natureza_juridica","natureza_juridica"="natureza_juridica",
  "Ind CEI Vinculado"="ind_cei_vinculado","IND CEI VINCULADO"="ind_cei_vinculado","ind_cei_vinculado"="ind_cei_vinculado",
  "Ind Simples"="ind_simples","IND SIMPLES"="ind_simples","ind_simples"="ind_simples",
  "Ind Estab Participa PAT"="ind_participa_pat","ind_pat"="ind_participa_pat","ind_participa_pat"="ind_participa_pat",
  # Remunera\u00e7\u00e3o
  "Vl Remun Dezembro Nom"="vl_remun_dezembro_nom","vl_remun_dezembro_nom"="vl_remun_dezembro_nom",
  "Vl Remun Dezembro (SM)"="vl_remun_dezembro_sm","vl_remun_dezembro_sm"="vl_remun_dezembro_sm",
  "Vl Remun M\u00e9dia Nom"="vl_remun_media_nom","Vl Remun Media Nom"="vl_remun_media_nom",
  "VL REMUN MEDIA NOM"="vl_remun_media_nom","vl_remun_media_nom"="vl_remun_media_nom",
  "Vl Remun M\u00e9dia (SM)"="vl_remun_media_sm","Vl Remun Media (SM)"="vl_remun_media_sm","vl_remun_media_sm"="vl_remun_media_sm",
  "Faixa Remun Dezem (SM)"="faixa_remun_dezembro_sm","faixa_remun_dezembro_sm"="faixa_remun_dezembro_sm",
  "Faixa Remun M\u00e9dia (SM)"="faixa_remun_media_sm","faixa_remun_media_sm"="faixa_remun_media_sm",
  "Vl \u00dalt Remun Ano"="vl_ultima_remun_ano","Vl Ult Remun Ano"="vl_ultima_remun_ano","vl_ultima_remuneracao_ano"="vl_ultima_remun_ano","vl_ultima_remun_ano"="vl_ultima_remun_ano",
  "Vl Sal\u00e1rio Contratual"="vl_salario_contratual","Vl Salario Contratual"="vl_salario_contratual","vl_salario_contratual"="vl_salario_contratual",
  "Tipo Sal\u00e1rio"="tipo_salario","Tipo Salario"="tipo_salario","tipo_salario"="tipo_salario",
  # Horas
  "Qtd Hora Contr"="qtd_horas_contratadas","QTD HORA CONTR"="qtd_horas_contratadas","qtd_hora_contr"="qtd_horas_contratadas","qtd_horas_contratadas"="qtd_horas_contratadas",
  "Faixa Hora Contrat"="faixa_horas_contratadas","faixa_horas_contratadas"="faixa_horas_contratadas",
  # Afastamentos
  "Causa Afastamento 1"="causa_afastamento_1","CAUSA AFASTAMENTO 1"="causa_afastamento_1","causa_afastamento_1"="causa_afastamento_1",
  "Causa Afastamento 2"="causa_afastamento_2","CAUSA AFASTAMENTO 2"="causa_afastamento_2","causa_afastamento_2"="causa_afastamento_2",
  "Causa Afastamento 3"="causa_afastamento_3","CAUSA AFASTAMENTO 3"="causa_afastamento_3","causa_afastamento_3"="causa_afastamento_3",
  "Qtd Dias Afastamento"="qtd_dias_afastamento","QTD DIAS AFASTAMENTO"="qtd_dias_afastamento","qtd_dias_afastamento"="qtd_dias_afastamento",
  # Controle
  "ano"="ano","year"="ano"
)

.DICT_ESTABELECIMENTOS <- c(
  "CNPJ CEI"="cnpj_cei","CNPJ"="cnpj_cei","cnpj_cei"="cnpj_cei",
  "Munic\u00edpio"="id_municipio","Municipio"="id_municipio","id_municipio"="id_municipio",
  "UF"="sigla_uf","uf"="sigla_uf","sigla_uf"="sigla_uf",
  "Natureza Jur\u00eddica"="natureza_juridica","Natureza Juridica"="natureza_juridica","natureza_juridica"="natureza_juridica",
  "Tipo Estab"="tipo_estabelecimento","tipo_estabelecimento"="tipo_estabelecimento",
  "Tamanho Estabelecimento"="tamanho_estabelecimento","tamanho_estabelecimento"="tamanho_estabelecimento",
  "CNAE 2.0 Classe"="cnae20_classe","cnae20_classe"="cnae20_classe",
  "Classe CNAE 95"="cnae95_classe","CLAS CNAE 95"="cnae95_classe","cnae95_classe"="cnae95_classe",
  "CNAE 2.0 Subclasse"="cnae20_subclasse","cnae20_subclasse"="cnae20_subclasse",
  "Qtd V\u00ednculos Ativos"="qtd_vinculos_ativos","Qtd Vinculos Ativos"="qtd_vinculos_ativos","qtd_vinculos_ativos"="qtd_vinculos_ativos",
  "Qtd V\u00ednculos CLT"="qtd_vinculos_clt","Qtd Vinculos CLT"="qtd_vinculos_clt","qtd_vinculos_clt"="qtd_vinculos_clt",
  "Qtd V\u00ednculos Estat"="qtd_vinculos_estat","Qtd Vinculos Estat"="qtd_vinculos_estat","qtd_vinculos_estat"="qtd_vinculos_estat",
  "Ind Simples"="ind_simples","ind_simples"="ind_simples",
  "Ind Estab Participa PAT"="ind_participa_pat","ind_pat"="ind_participa_pat",
  "ano"="ano","year"="ano"
)

#' Renomeia colunas da RAIS para snake_case PT consistente
#'
#' @param x data.frame ou conexão DuckDB.
#' @param table Quando `x` é conexão: tabela a renomear.
#' @param type `"vinculos"` (default) ou `"estabelecimentos"`.
#' @param keep_unknown Manter colunas não reconhecidas? Default: `TRUE`.
#' @param quiet Suprimir mensagens? Default: `FALSE`.
#'
#' @return data.frame renomeado, ou conexão invisível (side-effect no banco).
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   df_raw <- read.csv2("CE2022.txt", fileEncoding = "latin1")
#'   df     <- rais_rename_cols(df_raw)
#'   names(df)
#' }
#' }
#' @export
rais_rename_cols <- function(x, table = "vinculos",
                              type = c("vinculos", "estabelecimentos"),
                              keep_unknown = TRUE, quiet = FALSE) {
  type <- match.arg(type)
  dict <- if (type == "vinculos") .DICT_VINCULOS else .DICT_ESTABELECIMENTOS

  if (inherits(x, "DBIConnection"))
    return(.rename_db(x, table, dict, quiet))

  old <- names(x)
  new <- rep(NA_character_, length(old))  # NA_character_ para filtro correto
  nf  <- character(0)
  for (i in seq_along(old)) {
    nm <- old[i]
    if (nm %in% names(dict)) { new[i] <- dict[[nm]] } else {
      idx <- which(tolower(names(dict)) == tolower(nm))
      if (length(idx) > 0) { new[i] <- dict[[idx[1]]] } else {
        nf <- c(nf, nm)
        if (keep_unknown) {
          new[i] <- nm  # else: deixa NA e sera removido abaixo
        }
      }
    }
  }
  if (length(nf) > 0 && !quiet) {
    if (keep_unknown)
      cli::cli_alert_warning(
        .tr("%d unrecognised column(s) kept as-is: %s", length(nf), paste(nf, collapse=", "))
      )
    else
      cli::cli_alert_warning(
        .tr("%d unrecognised column(s) dropped: %s", length(nf), paste(nf, collapse=", "))
      )
  }
  if (!keep_unknown) {
    keep <- !is.na(new)
    x    <- x[, keep, drop = FALSE]
    new  <- new[keep]
  }
  names(x) <- new; x
}

#' Exibe o dicionário de nomes de colunas
#'
#' @param type `"vinculos"` ou `"estabelecimentos"`.
#' @param search String para filtrar (busca em original e normalizado).
#' @return data.frame com `original` e `normalizado`.
#' @examples
#' rais_col_dictionary(search = "remun")
#' @export
rais_col_dictionary <- function(type = c("vinculos","estabelecimentos"), search = NULL) {
  type <- match.arg(type)
  dict <- if (type == "vinculos") .DICT_VINCULOS else .DICT_ESTABELECIMENTOS
  out  <- data.frame(original=names(dict), normalizado=unname(dict), stringsAsFactors=FALSE)
  out  <- out[!duplicated(out$original), ]
  if (!is.null(search)) {
    pat  <- tolower(search)
    mask <- grepl(pat, tolower(out$original)) | grepl(pat, tolower(out$normalizado))
    out  <- out[mask, ]
  }
  rownames(out) <- NULL; out
}

#' Traduz vetor de nomes de colunas pelo dicionário
#' @param cols Vetor de nomes.
#' @param type `"vinculos"` ou `"estabelecimentos"`.
#' @return Vetor traduzido (não reconhecidos mantidos).
#' @examples
#' rais_translate_cols(c("Vl Remun Média Nom", "Sexo Trabalhador"))
#' @export
rais_translate_cols <- function(cols, type = c("vinculos","estabelecimentos")) {
  type <- match.arg(type)
  dict <- if (type == "vinculos") .DICT_VINCULOS else .DICT_ESTABELECIMENTOS
  vapply(cols, function(nm) {
    if (nm %in% names(dict)) return(dict[[nm]])
    idx <- which(tolower(names(dict)) == tolower(nm))
    if (length(idx) > 0) return(dict[[idx[1]]])
    nm
  }, character(1), USE.NAMES = FALSE)
}

#' @noRd
.rename_db <- function(con, table, dict, quiet) {
  if (!DBI::dbExistsTable(con, table))
    cli::cli_abort(.tr("Table '%s' not found in the database.", table))
  current <- DBI::dbListFields(con, table); n_done <- 0L; kept <- character(0)
  for (col in current) {
    new_col <- NULL
    if (col %in% names(dict)) { new_col <- dict[[col]] } else {
      idx <- which(tolower(names(dict)) == tolower(col))
      if (length(idx) > 0) new_col <- dict[[idx[1]]]
    }
    if (!is.null(new_col) && new_col != col) {
      tryCatch({
        DBI::dbExecute(con, glue::glue('ALTER TABLE "{table}" RENAME COLUMN "{col}" TO "{new_col}"'))
        n_done <- n_done + 1L
        if (!quiet) cli::cli_alert_success(.tr("  %s \u2192 %s", col, new_col))
      }, error = function(e) cli::cli_alert_warning(.tr("  Could not rename %s: %s", col, conditionMessage(e))))
    } else if (is.null(new_col)) kept <- c(kept, col)
  }
  if (!quiet) {
    cli::cli_alert_success(.tr("%d column(s) renamed in table '%s'", n_done, table))
    if (length(kept) > 0) cli::cli_alert_info(.tr("Kept unchanged: %s", paste(kept, collapse=", ")))
  }
  invisible(con)
}


#' Metadados de variáveis da RAIS
#'
#' Retorna informações sobre uma ou mais variáveis: tipo SQL, tipo R,
#' período de disponibilidade e descrição. Útil para entender o schema
#' antes de carregar dados.
#'
#' @param col character ou NULL. Nome(s) de coluna(s) no padrão snake_case.
#'   `NULL` retorna todas as colunas disponíveis.
#' @param type character. `"vinculos"`, `"estabelecimentos"` ou `"all"`.
#'   Default: `"vinculos"`.
#' @param search character ou NULL. Filtra colunas cujo nome ou descrição
#'   contenha o texto (case-insensitive). Ex: `search = "remun"`.
#'
#' @return tibble com colunas:
#'   - `coluna` — nome snake_case
#'   - `descricao` — descrição em português
#'   - `tipo_r` — tipo R (`integer`, `double`, `character`)
#'   - `tipo_sql` — tipo DuckDB (`INTEGER`, `DOUBLE`, `VARCHAR`)
#'   - `tabela` — `rais_antigo`, `rais_novo`, `rais_estab` ou `ambas`
#'   - `disponivel_desde` — primeiro ano com a variável
#'   - `disponivel_ate` — último ano (NA = ainda disponível)
#'
#' @examples
#' # Todas as variáveis de vínculos
#' rais_col_info()
#'
#' # Busca por variáveis de remuneração
#' rais_col_info(search = "remun")
#'
#' # Informação de coluna específica
#' rais_col_info("vl_remun_media_nom")
#'
#' @seealso [rais_col_dictionary()], [rais_rename_cols()]
#' @export
rais_col_info <- function(col    = NULL,
                           type   = "vinculos",
                           search = NULL) {
  type <- match.arg(type, c("vinculos", "estabelecimentos", "all"))

  # Dicionário de metadados
  meta <- .COL_META[.COL_META$tipo %in% switch(type,
    vinculos         = c("vinculos", "ambas"),
    estabelecimentos = c("estab",    "ambas"),
    all              = c("vinculos", "estab", "ambas")
  ), ]

  # Filtro por nome
  if (!is.null(col)) {
    meta <- meta[meta$coluna %in% col, ]
    nao_encontradas <- setdiff(col, meta$coluna)
    if (length(nao_encontradas) > 0)
      cli::cli_warn("Coluna(s) n\u00e3o encontradas: {.val {nao_encontradas}}")
  }

  # Filtro por texto
  if (!is.null(search) && nzchar(search)) {
    idx  <- grepl(search, meta$coluna,    ignore.case = TRUE) |
            grepl(search, meta$descricao, ignore.case = TRUE)
    meta <- meta[idx, ]
  }

  if (nrow(meta) == 0L) {
    cli::cli_inform("Nenhuma vari\u00e1vel encontrada.")
    return(invisible(tibble::tibble()))
  }

  tibble::as_tibble(meta)
}

# -- Tabela de metadados de colunas -------------------------------------------

#' @noRd
.COL_META <- local({
  v <- function(coluna, descricao, tipo_r, tipo_sql, tabela,
                desde = 1985L, ate = NA_integer_) {
    data.frame(coluna = coluna, descricao = descricao,
               tipo_r = tipo_r, tipo_sql = tipo_sql, tipo = tabela,
               disponivel_desde = desde, disponivel_ate = ate,
               stringsAsFactors = FALSE)
  }
  rbind(
    # ── Identificação ──────────────────────────────────────────────
    v("ano",              "Ano de refer\u00eancia",
      "integer","INTEGER","ambas"),
    v("sigla_uf",         "C\u00f3digo IBGE da UF (ex: 23 = CE)",
      "integer","INTEGER","ambas"),
    v("id_municipio",     "C\u00f3digo IBGE do munic\u00edpio (7 d\u00edgitos)",
      "integer","INTEGER","ambas"),
    # ── Trabalhador ────────────────────────────────────────────────
    v("sexo",             "Sexo do trabalhador (1=Masc, 3=Fem)",
      "integer","INTEGER","vinculos"),
    v("idade",            "Idade do trabalhador em anos",
      "integer","INTEGER","vinculos"),
    v("grau_instrucao",   "Grau de instru\u00e7\u00e3o (c\u00f3digo)",
      "integer","INTEGER","vinculos"),
    v("raca_cor",         "Ra\u00e7a/cor (IBGE: 1=Branca, 2=Preta...)",
      "integer","INTEGER","vinculos", desde = 1999L),
    v("nacionalidade",    "Nacionalidade do trabalhador",
      "integer","INTEGER","vinculos"),
    v("portador_defic",   "Portador de defici\u00eancia (0/1)",
      "integer","INTEGER","vinculos"),
    # ── Ocupação ───────────────────────────────────────────────────
    v("cbo_2002",         "CBO Ocupa\u00e7\u00e3o 2002 (6 d\u00edgitos)",
      "character","VARCHAR","vinculos", desde = 2003L),
    v("cbo_94",           "CBO Ocupa\u00e7\u00e3o 1994 (5 d\u00edgitos)",
      "character","VARCHAR","vinculos", ate = 2009L),
    # ── Remuneração ────────────────────────────────────────────────
    v("vl_remun_media_nom","Remunera\u00e7\u00e3o m\u00e9dia nominal (R$)",
      "double","DOUBLE","vinculos"),
    v("vl_remun_media_sm", "Remunera\u00e7\u00e3o m\u00e9dia em sal\u00e1rios m\u00ednimos",
      "double","DOUBLE","vinculos"),
    v("vl_remun_dezembro_nom","Remunera\u00e7\u00e3o em dezembro (R$)",
      "double","DOUBLE","vinculos"),
    v("vl_remun_dezembro_sm", "Remunera\u00e7\u00e3o em dezembro em SM",
      "double","DOUBLE","vinculos"),
    # ── Horas ──────────────────────────────────────────────────────
    v("qtd_horas_contratadas","Horas semanais contratadas",
      "integer","INTEGER","vinculos"),
    v("faixa_horas_contratadas","Faixa de horas semanais contratadas",
      "integer","INTEGER","vinculos"),
    # ── Contrato ───────────────────────────────────────────────────
    v("tipo_vinculo",     "Tipo de v\u00ednculo (CLT, estatut\u00e1rio...)",
      "integer","INTEGER","vinculos"),
    v("causa_desligamento","Causa do desligamento",
      "integer","INTEGER","vinculos"),
    v("meses_emprego",    "Meses no emprego atual",
      "integer","INTEGER","vinculos"),
    v("ind_trab_intermit","Trabalho intermitente (0/1)",
      "integer","INTEGER","vinculos", desde = 2017L),
    v("ind_trab_parcial", "Trabalho em tempo parcial (0/1)",
      "integer","INTEGER","vinculos", desde = 2017L),
    # ── Estabelecimento (v\u00ednculos) ────────────────────────────────────
    v("cnpj_cei",         "CNPJ ou CEI do estabelecimento",
      "character","VARCHAR","vinculos"),
    v("cnae20_subclasse", "CNAE 2.0 Subclasse (7 d\u00edgitos)",
      "character","VARCHAR","vinculos", desde = 2006L),
    v("cnae20_classe",    "CNAE 2.0 Classe (5 d\u00edgitos)",
      "character","VARCHAR","vinculos", desde = 2006L),
    v("cnae20_grupo",     "CNAE 2.0 Grupo (3 d\u00edgitos)",
      "character","VARCHAR","vinculos", desde = 2006L),
    v("cnae20_divisao",   "CNAE 2.0 Divis\u00e3o (2 d\u00edgitos)",
      "character","VARCHAR","vinculos", desde = 2006L),
    v("cnae20_secao",     "CNAE 2.0 Se\u00e7\u00e3o (letra)",
      "character","VARCHAR","vinculos", desde = 2006L),
    v("cnae95_classe",    "CNAE 1.0 Classe (5 d\u00edgitos)",
      "character","VARCHAR","vinculos", ate = 2005L),
    v("tamanho_estabelecimento","Faixa de tamanho do estabelecimento",
      "integer","INTEGER","vinculos"),
    v("natureza_juridica", "Natureza jur\u00eddica do estabelecimento",
      "character","VARCHAR","vinculos"),
    v("ind_simples",      "Optante pelo Simples Nacional (0/1)",
      "integer","INTEGER","vinculos"),
    v("ind_aprendiz",     "Aprendiz (0/1)",
      "integer","INTEGER","vinculos"),
    # ── Estabelecimentos ───────────────────────────────────────────
    v("cnpj_raiz",        "CNPJ raiz do estabelecimento (8 d\u00edgitos)",
      "character","VARCHAR","estab"),
    v("qtd_vinculos_ativos","N\u00famero de v\u00ednculos ativos em 31/12",
      "integer","INTEGER","estab"),
    v("qtd_vinculos_clt", "V\u00ednculos CLT ativos",
      "integer","INTEGER","estab"),
    v("qtd_vinculos_estat","V\u00ednculos estatut\u00e1rios ativos",
      "integer","INTEGER","estab"),
    # ── Meta (adicionadas pelo pacote) ─────────────────────────────
    v("fonte_tipo",       "Tipo da fonte: vinculos_antigo, vinculos_novo, estab",
      "character","VARCHAR","ambas")
  )
})
