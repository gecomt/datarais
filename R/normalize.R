# normalize.R
# Pipeline de normaliza\u00e7\u00e3o de nomes de colunas \u2014 SOLU\u00c7\u00c3O DO PROBLEMA 1
#
# Estrat\u00e9gia correta (3 tentativas em cascata):
#   1. Busca o nome original no dicion\u00e1rio (case-sensitive)
#   2. Busca o nome original no dicion\u00e1rio (case-insensitive)
#   3. Normaliza o nome (remove acentos, min\u00fascula, snake_case)
#      e tenta novamente no dicion\u00e1rio
#   4. Fallback: usa o nome normalizado sem mapeamento
#
# Isso garante que "Faixa Hora Contrat" \u2192 "qtd_horas_contratadas"
# (via busca original no dict) em vez de "faixa_hora_contrat" (errado).

#' Normaliza nomes de colunas da RAIS com pipeline de 4 tentativas
#'
#' Resolve o problema da normalização em dois passos, onde
#' `.normalize_col_names()` aplicado antes do dicionário produzia
#' nomes intermediários que o dicionário não reconhecia.
#'
#' @param raw_names character. Nomes originais do arquivo .txt.
#' @param dict list/named character. Dicionário original → normalizado.
#' @return character. Nomes normalizados.
#' @noRd
.normalize_pipeline <- function(raw_names, dict) {
  result    <- character(length(raw_names))
  unmapped  <- character(0)

  for (i in seq_along(raw_names)) {
    nm <- raw_names[i]

    # Tentativa 1: nome original, case-sensitive
    if (nm %in% names(dict)) {
      result[i] <- dict[[nm]]
      next
    }

    # Tentativa 2: nome original, case-insensitive
    idx <- which(tolower(names(dict)) == tolower(nm))
    if (length(idx) > 0L) {
      result[i] <- dict[[idx[1L]]]
      next
    }

    # Tentativa 3: normaliza o nome e tenta no dicion\u00e1rio
    nm_norm <- .snake_clean(nm)
    if (nm_norm %in% names(dict)) {
      result[i] <- dict[[nm_norm]]
      next
    }
    idx2 <- which(tolower(names(dict)) == tolower(nm_norm))
    if (length(idx2) > 0L) {
      result[i] <- dict[[idx2[1L]]]
      next
    }

    # Tentativa 4: fallback \u2014 usa nome normalizado (sem mapeamento)
    result[i] <- nm_norm
    unmapped  <- c(unmapped, nm)
  }

  attr(result, "unmapped") <- unmapped
  result
}

#' Limpeza genérica de nome → snake_case sem acentos
#' @noRd
.snake_clean <- function(nm) {
  nm <- trimws(nm)
  nm <- gsub("\uFEFF", "", nm, fixed = FALSE)
  nm <- gsub("\u00e1|\u00e0|\u00e3|\u00e2|\u00e4", "a", nm)
  nm <- gsub("\u00e9|\u00e8|\u00ea|\u00eb",         "e", nm)
  nm <- gsub("\u00ed|\u00ec|\u00ee|\u00ef",         "i", nm)
  nm <- gsub("\u00f3|\u00f2|\u00f5|\u00f4|\u00f6", "o", nm)
  nm <- gsub("\u00fa|\u00f9|\u00fb|\u00fc",         "u", nm)
  nm <- gsub("\u00e7",                                  "c", nm)
  nm <- tolower(nm)
  nm <- gsub("[^a-z0-9]+", "_", nm)
  nm <- gsub("_+",          "_", nm)
  nm <- gsub("^_|_$",       "",  nm)
  nm
}

#' Resolve colunas duplicadas após normalização
#'
#' Se dois nomes originais mapearem para o mesmo nome normalizado
#' (ex: "ind_simples_2" e "ind_simples_3" → ambos "ind_simples"),
#' sufixos _2, _3, ... são adicionados a partir da segunda ocorrência.
#' @noRd
.dedup_names <- function(nomes) {
  seen   <- list()   # contagem de vezes que cada nome foi usado
  used   <- list()   # conjunto de nomes j\u00e1 atribu\u00eddos (para detectar colis\u00f5es)
  result <- character(length(nomes))

  for (i in seq_along(nomes)) {
    nm    <- nomes[i]
    cnt   <- seen[[nm]] %||% 0L
    cand  <- if (cnt == 0L) nm else paste0(nm, "_", cnt + 1L)

    # Se o candidato j\u00e1 foi usado (colis\u00e3o com nome pr\u00e9-existente), incrementa
    while (!is.null(used[[cand]])) {
      cnt  <- cnt + 1L
      cand <- paste0(nm, "_", cnt + 1L)
    }

    result[i]   <- cand
    seen[[nm]]  <- cnt + 1L
    used[[cand]] <- TRUE
  }
  result
}

#' Aplica o pipeline completo de normalização a um data.frame
#'
#' Substitui os passos separados `.normalize_col_names()` + `rais_rename_cols()`
#' por um único pipeline coerente que não perde mapeamentos.
#'
#' @param df data.frame com nomes originais.
#' @param dict_type "vinculos" ou "estabelecimentos".
#' @param quiet suprimir avisos sobre colunas não mapeadas? Default: FALSE.
#' @return data.frame com nomes normalizados.
#' @noRd
.apply_normalize_pipeline <- function(df, dict_type = "vinculos", quiet = FALSE) {
  # .DICT_VINCULOS e .DICT_ESTABELECIMENTOS definidos em rename.R
  # (todos os arquivos R do pacote compartilham o mesmo namespace)
  dict <- if (dict_type == "vinculos") .DICT_VINCULOS else .DICT_ESTABELECIMENTOS

  # Remove colunas artificiais do readr ("...1", "...2", etc.)
  df <- df[, !grepl("^[.][.][.]\\d+$", names(df)), drop = FALSE]

  # Remove colunas com nome vazio
  df <- df[, nchar(names(df)) > 0L, drop = FALSE]

  # Pipeline de normaliza\u00e7\u00e3o
  new_names <- .normalize_pipeline(names(df), dict)
  unmapped  <- attr(new_names, "unmapped")

  # Resolve duplicatas
  new_names <- .dedup_names(new_names)
  names(df) <- new_names

  if (length(unmapped) > 0L && !quiet) {
    cli::cli_warn(c(
      .tr("%d unrecognised column(s) kept as-is: %s",
          length(unmapped), paste(unmapped, collapse = ", ")),
      "i" = "Add to .DICT_VINCULOS or .DICT_ESTABELECIMENTOS in rename.R."
    ))
  }

  df
}
