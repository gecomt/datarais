# schema.R
# Schema can\u00f4nico das tabelas DuckDB da RAIS
#
# Define os tipos de cada coluna ANTES do primeiro INSERT.
# Garante que todos os anos sejam inseridos no mesmo schema,
# independentemente da ordem de carga ou do layout do arquivo.
#
# Princ\u00edpio: VARCHAR para tudo que \u00e9 categ\u00f3rico ou identificador;
#            DOUBLE para valores num\u00e9ricos cont\u00ednuos;
#            INTEGER para c\u00f3digos, contagens e flags.

# -- Schema de v\u00ednculos (rais_antigo e rais_novo) ------------------------------

#' Schema canônico da tabela de vínculos
#'
#' Colunas presentes em TODOS os layouts (1985-atual).
#' Colunas de layouts específicos são adicionadas dinamicamente
#' via ALTER TABLE ADD COLUMN com tipo definido aqui.
#' @noRd
.SCHEMA_VINCULOS <- c(
  # Controle
  ano                      = "INTEGER",   # adicionado pelo pacote
  fonte_tipo               = "VARCHAR",   # adicionado pelo pacote

  # Identifica\u00e7\u00e3o geogr\u00e1fica
  id_municipio             = "INTEGER",
  sigla_uf                 = "INTEGER",   # c\u00f3digo IBGE num\u00e9rico (ex: 23 = CE, 35 = SP)

  # V\u00ednculo
  vinculo_ativo_3112       = "INTEGER",
  tipo_vinculo             = "INTEGER",
  tipo_admissao            = "INTEGER",
  mes_admissao             = "INTEGER",
  data_admissao            = "VARCHAR",   # formato varia entre anos
  motivo_desligamento      = "INTEGER",
  mes_desligamento         = "INTEGER",
  tempo_emprego            = "DOUBLE",
  faixa_tempo_emprego      = "INTEGER",

  # Trabalhador
  sexo                     = "INTEGER",
  raca_cor                 = "INTEGER",   # ausente antes de 1999 \u2192 NULL
  idade                    = "INTEGER",
  faixa_etaria             = "INTEGER",
  nacionalidade            = "INTEGER",
  ind_portador_defic       = "INTEGER",
  tipo_deficiencia         = "INTEGER",

  # Escolaridade
  grau_instrucao           = "INTEGER",

  # Ocupa\u00e7\u00e3o
  cbo_94                   = "VARCHAR",   # ausente ap\u00f3s 2002 \u2192 NULL
  cbo_2002                 = "VARCHAR",   # ausente antes de 2003 \u2192 NULL

  # CNAE
  cnae95_classe            = "VARCHAR",   # ausente ap\u00f3s ~2006 \u2192 NULL
  cnae20_classe            = "VARCHAR",   # ausente antes de 2006 \u2192 NULL
  cnae20_subclasse         = "VARCHAR",   # ausente antes de 2006 \u2192 NULL

  # Estabelecimento (no registro de v\u00ednculo)
  tamanho_estabelecimento  = "INTEGER",
  tipo_estabelecimento     = "INTEGER",
  natureza_juridica        = "INTEGER",
  ind_simples              = "INTEGER",
  ind_cei_vinculado        = "INTEGER",
  ind_participa_pat        = "INTEGER",

  # Remunera\u00e7\u00e3o
  vl_remun_dezembro_nom    = "DOUBLE",
  vl_remun_dezembro_sm     = "DOUBLE",
  vl_remun_media_nom       = "DOUBLE",
  vl_remun_media_sm        = "DOUBLE",
  faixa_remun_dezembro_sm  = "INTEGER",
  faixa_remun_media_sm     = "INTEGER",
  vl_ultima_remun_ano      = "DOUBLE",
  vl_salario_contratual    = "DOUBLE",
  tipo_salario             = "INTEGER",

  # Horas
  qtd_horas_contratadas    = "INTEGER",
  faixa_horas_contratadas  = "INTEGER",

  # Afastamentos
  causa_afastamento_1      = "INTEGER",
  causa_afastamento_2      = "INTEGER",
  causa_afastamento_3      = "INTEGER",
  qtd_dias_afastamento     = "INTEGER",

  # Vari\u00e1veis do layout novo (2020+)
  ind_trab_intermitente    = "INTEGER",
  ind_trab_parcial         = "INTEGER",

  # Vari\u00e1veis do layout antigo
  ibge_subsetor            = "INTEGER",
  subsetor                 = "INTEGER",
  subatividade             = "INTEGER",
  saldo_mov                = "INTEGER"
)

#' Schema canônico de estabelecimentos
#' @noRd
.SCHEMA_ESTAB <- c(
  ano                      = "INTEGER",
  fonte_tipo               = "VARCHAR",
  cnpj_cei                 = "VARCHAR",
  id_municipio             = "INTEGER",
  sigla_uf                 = "INTEGER",
  natureza_juridica        = "INTEGER",
  tipo_estabelecimento     = "INTEGER",
  tamanho_estabelecimento  = "INTEGER",
  cnae95_classe            = "VARCHAR",
  cnae20_classe            = "VARCHAR",
  cnae20_subclasse         = "VARCHAR",
  qtd_vinculos_ativos      = "INTEGER",
  qtd_vinculos_clt         = "INTEGER",
  qtd_vinculos_estat       = "INTEGER",
  ind_simples              = "INTEGER",
  ind_participa_pat        = "INTEGER"
)

#' Schema canônico de trabalho doméstico
#' @noRd
.SCHEMA_DOMESTICO <- c(
  ano                      = "INTEGER",
  fonte_tipo               = "VARCHAR",
  id_municipio             = "INTEGER",
  sigla_uf                 = "INTEGER",
  sexo                     = "INTEGER",
  raca_cor                 = "INTEGER",
  idade                    = "INTEGER",
  grau_instrucao           = "INTEGER",
  tipo_vinculo             = "INTEGER",
  mes_admissao             = "INTEGER",
  motivo_desligamento      = "INTEGER",
  mes_desligamento         = "INTEGER",
  tempo_emprego            = "DOUBLE",
  vl_remun_media_nom       = "DOUBLE",
  vl_remun_media_sm        = "DOUBLE",
  vl_remun_dezembro_nom    = "DOUBLE",
  vl_remun_dezembro_sm     = "DOUBLE",
  qtd_horas_contratadas    = "INTEGER",
  natureza_juridica        = "INTEGER",
  tamanho_estabelecimento  = "INTEGER",
  cnae20_subclasse         = "VARCHAR"
)

#' Mapa: nome de tabela → schema canônico
#' @noRd
.SCHEMAS <- list(
  rais_antigo   = .SCHEMA_VINCULOS,
  rais_novo     = .SCHEMA_VINCULOS,
  rais_estab    = .SCHEMA_ESTAB,
  rais_domestico = .SCHEMA_DOMESTICO
)

#' Tipo canônico de uma coluna, dada uma tabela
#' Retorna "VARCHAR" como fallback seguro para colunas desconhecidas.
#' @noRd
.col_type_canonico <- function(table, col_name) {
  schema <- .SCHEMAS[[table]]
  if (is.null(schema)) return("VARCHAR")
  schema[[col_name]] %||% "VARCHAR"
}

# -- Cria\u00e7\u00e3o de tabela com schema can\u00f4nico -------------------------------------

#' Cria uma tabela DuckDB com o schema canônico da RAIS
#'
#' Chamado antes do primeiro INSERT para garantir que os tipos de todas as
#' colunas estão definidos independentemente do primeiro ano carregado.
#'
#' @param con conexão DuckDB.
#' @param table nome da tabela.
#' @noRd
.create_table_canonical <- function(con, table) {
  schema <- .SCHEMAS[[table]]
  if (is.null(schema)) {
    cli::cli_abort(.tr("No canonical schema for table {.val %s}.", table))
  }

  col_defs <- paste(
    sprintf('"%s" %s', names(schema), unname(schema)),
    collapse = ",\n  "
  )
  sql <- sprintf('CREATE TABLE IF NOT EXISTS "%s" (\n  %s\n)', table, col_defs)
  DBI::dbExecute(con, sql)
  cli::cli_inform(.tr("Table {.val %s} created with canonical schema (%d columns).",
                       table, length(schema)))
}

#' Adiciona ao schema canônico colunas novas do df (não previstas)
#' @noRd
.sync_schema <- function(con, table, df) {
  existing   <- DBI::dbListFields(con, table)
  df_cols    <- names(df)
  new_cols   <- setdiff(df_cols, existing)

  for (col in new_cols) {
    tipo <- .col_type_canonico(table, col)
    tryCatch({
      DBI::dbExecute(con, sprintf(
        'ALTER TABLE "%s" ADD COLUMN "%s" %s', table, col, tipo
      ))
      cli::cli_inform(.tr("New column {.col %s} added to {.val %s} as %s.",
                           col, table, tipo))
    }, error = function(e) {
      cli::cli_warn(.tr("Could not add column {.col %s}: %s",
                         col, conditionMessage(e)))
    })
  }
}

# -- Alinhamento e coer\u00e7\u00e3o de tipos -------------------------------------------

#' Alinha o data.frame ao schema canônico antes do INSERT
#'
#' 1. Adiciona colunas ausentes (com NA do tipo correto)
#' 2. Coerce cada coluna para o tipo do schema
#' 3. Reordena conforme o schema
#' @noRd
.align_to_schema <- function(df, table) {
  schema <- .SCHEMAS[[table]] %||% return(df)
  for (col in names(schema)) {
    tipo <- schema[[col]]
    if (!col %in% names(df)) {
      # Coluna ausente neste ano/layout \u2192 preenche com NA do tipo correto
      df[[col]] <- switch(tipo,
        INTEGER = NA_integer_,
        DOUBLE  = NA_real_,
        NA_character_
      )
    } else {
      # Coerce para o tipo can\u00f4nico
      df[[col]] <- .cast_col(df[[col]], tipo)
    }
  }

  # Colunas extras (n\u00e3o no schema can\u00f4nico) ficam ao final, sem coer\u00e7\u00e3o for\u00e7ada
  extras <- setdiff(names(df), names(schema))
  df[c(names(schema), extras)]
}

#' Coerce um vetor para o tipo DuckDB especificado
#' @noRd
.cast_col <- function(x, tipo) {
  switch(tipo,
    INTEGER = {
      if (is.integer(x)) return(x)
      suppressWarnings(as.integer(gsub("[^0-9-]", "", as.character(x))))
    },
    DOUBLE = {
      if (is.double(x)) return(x)
      s <- as.character(x)
      # Remove pontos de milhar (1.234,56 \u2192 1234,56) ANTES de trocar v\u00edrgula
      s <- gsub("\\.", "", s)          # remove ponto de milhar
      s <- gsub(",", ".", s)           # troca v\u00edrgula decimal por ponto
      suppressWarnings(as.numeric(s))
    },
    # VARCHAR: converte tudo para character
    as.character(x)
  )
}
