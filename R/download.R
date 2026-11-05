# download.R
# Download de arquivos do HuggingFace com retry, cache e paralelismo

# -- Constru\u00e7\u00e3o de URLs --------------------------------------------------------

#' Constri URL HTTPS do arquivo no repositorio HuggingFace
#'
#' Estrutura real (tudo em RAIS/{ano}/):
#'   RAIS/{ano}/{UF}{ano}.7z              (vinculos antigo, < 2018)
#'   RAIS/{ano}/ESTB{ano}.7z              (estab antigo, < 2018)
#'   RAIS/{ano}/RAIS_VINC_PUB_{REG}.7z   (vinculos novo, >= 2018)
#'   RAIS/{ano}/RAIS_ESTAB_PUB.7z        (estab novo, >= 2018)
#' @noRd
.hf_url_rais <- function(year, type, uf = NULL, regiao = NULL,
                          pasta_ano = NULL) {
  # pasta_ano permite "2023 Parcial" em vez de "2023"
  subdir_ano <- pasta_ano %||% as.character(year)
  # URLencode para suportar pastas com espaço (ex: "2023 Parcial")
  subdir     <- paste0(.HF_PASTA_RAIS, "/",
                       utils::URLencode(subdir_ano, repeated = TRUE))

  if (.is_rais_novo(year)) {
    if (type == "estab") {
      nome <- "RAIS_ESTAB_PUB.7z"
    } else {
      if (is.null(regiao))
        cli::cli_abort("regiao required for novo layout.")
      nome <- glue::glue("RAIS_VINC_PUB_{regiao}.7z")
    }
  } else {
    if (type == "estab") {
      nome <- as.character(.nome_estab(year))
    } else {
      if (is.null(uf))
        cli::cli_abort("uf required for antigo layout.")
      nome <- glue::glue("{uf}{year}.7z")
    }
  }

  list(
    url          = glue::glue("{.HF_BASE}/{subdir}/{nome}"),
    nome_arquivo = nome,
    subdir       = subdir
  )
}

# -- Download de um arquivo com retry ------------------------------------------

#' Baixa um arquivo do HuggingFace com retry exponencial
#' @noRd
.download_file <- function(url, destfile, timeout = 300,
                            sleep_fn = getOption("datarais.sleep_fn",
                                                  Sys.sleep)) {
  for (tentativa in seq_len(3L)) {
    resultado <- tryCatch({
      # Stream straight to disk (files can be several GB) via a .part file
      parcial <- paste0(destfile, ".part")
      on.exit(if (file.exists(parcial)) unlink(parcial), add = TRUE)
      resp <- httr2::request(url) |>
        httr2::req_timeout(timeout) |>
        httr2::req_retry(max_tries = 1L) |>
        httr2::req_error(is_error = \(r) FALSE) |>
        httr2::req_perform(path = parcial)

      status <- httr2::resp_status(resp)
      if (status %in% c(404L, 403L)) {
        if (file.exists(destfile)) unlink(destfile)
        return(invisible(NULL))
      }
      if (status >= 400L) return(1L)

      if (!file.rename(parcial, destfile)) {
        file.copy(parcial, destfile, overwrite = TRUE)
      }
      0L
    }, error = function(e) 1L)

    if (identical(resultado, 0L) &&
        file.exists(destfile) && file.size(destfile) > 0L)
      return(invisible(destfile))

    if (tentativa < 3L) sleep_fn(5L * tentativa)
  }

  if (file.exists(destfile)) unlink(destfile)
  cli::cli_warn(.tr("Failed to download {.url %s} after 3 attempts.", url))
  invisible(NULL)
}

# -- Montagem de tarefas -------------------------------------------------------

#' Gera tabela de tarefas de download
#' @noRd

.build_tasks_rais <- function(years, type, states, include_estab, include_partial = FALSE) {
  today <- Sys.Date()
  rows  <- list()

  # Adds the tasks of one HuggingFace year folder (e.g. "2023" or "2023 Parcial")
  add_pasta <- function(year, pasta_ano) {
    mk <- function(u, tipo, scope) {
      tibble::tibble(
        ano          = year,
        type         = tipo,
        scope        = scope,
        url          = u$url,
        nome_arquivo = u$nome_arquivo,
        subdir       = u$subdir
      )
    }
    out <- list()

    if (type %in% c("vinculos", "all")) {
      if (.is_rais_novo(year)) {
        regioes <- if (year >= 2022L) c(.REGIOES_NOVO, .REGIAO_NI) else .REGIOES_NOVO
        for (reg in regioes) {
          u <- .hf_url_rais(year, type = "vinc", regiao = reg, pasta_ano = pasta_ano)
          out[[length(out) + 1L]] <- mk(u, "vinculos_novo", reg)
        }
      } else {
        ufs <- if (!is.null(states)) states else names(.UF_CODIGOS)
        for (uf in ufs) {
          u <- .hf_url_rais(year, type = "vinc", uf = uf, pasta_ano = pasta_ano)
          out[[length(out) + 1L]] <- mk(u, "vinculos_antigo", uf)
        }
      }
    }

    if (include_estab || type %in% c("estabelecimentos", "all")) {
      u <- .hf_url_rais(year, type = "estab", pasta_ano = pasta_ano)
      out[[length(out) + 1L]] <- mk(u, "estab", "BR")
    }
    out
  }

  for (year in years) {
    if (as.Date(sprintf("%04d-12-31", year)) > today && !include_partial) next

    rows <- c(rows, add_pasta(year, as.character(year)))

    # Preliminary release ("2023 Parcial"), only on request
    if (include_partial) {
      pasta_parcial <- paste(year, "Parcial")
      if (!is.na(.hf_ano_existe(pasta_parcial)))
        rows <- c(rows, add_pasta(year, pasta_parcial))
    }
  }

  if (length(rows) == 0L) return(tibble::tibble())
  dplyr::bind_rows(rows)
}

# -- Execu\u00e7\u00e3o dos downloads ----------------------------------------------------

#' Executa downloads com suporte a paralelo e barra de progresso
#' @noRd
.run_downloads <- function(tasks, cache, force, timeout, workers = 1L) {
  n         <- nrow(tasks)
  destfiles <- file.path(cache, tasks$subdir, tasks$nome_arquivo)
  dirs      <- unique(dirname(destfiles))
  for (d in dirs) if (!dir.exists(d)) dir.create(d, recursive = TRUE)

  .processar <- function(i) {
    t        <- tasks[i, ]
    destfile <- destfiles[i]
    status   <- if (.is_cached(destfile) && !force) {
      "cache"
    } else {
      res <- .download_file(t$url, destfile, timeout)
      if (is.null(res)) "nao_encontrado"
      else if (.is_cached(destfile)) "baixado"
      else "erro"
    }
    tibble::tibble(
      arquivo      = destfile,
      ano          = t$ano,
      type         = t$type,
      scope        = t$scope,
      status       = status
    )
  }

  if (workers <= 1L) {
    resultados <- vector("list", n)
    cli::cli_progress_bar(
      name   = .tr("Downloading"),
      total  = n,
      format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} [{cli::pb_elapsed}] ETA: {cli::pb_eta_str}"
    )
    for (i in seq_len(n)) {
      resultados[[i]] <- .processar(i)
      cli::cli_progress_update()
    }
    cli::cli_progress_done()
  } else {
    oplan <- future::plan(future::multisession, workers = workers)
    on.exit(future::plan(oplan), add = TRUE)
    # progressr com furrr: p() deve ser chamado no processo pai, n\u00e3o no worker
    # Usamos callbacks via .progress do furrr para atualizar o progressor
    progressr::with_progress({
      p <- progressr::progressor(steps = n)
      resultados <- furrr::future_map(
        seq_len(n),
        function(i) .processar(i),
        .options  = furrr::furrr_options(seed = NULL),
        .progress = TRUE   # barra de progresso nativa do furrr
      )
      p(amount = n)  # avan\u00e7a o progressor do pai para 100% ao final
    })
  }

  dplyr::bind_rows(resultados)
}

# -- Fun\u00e7\u00e3o p\u00fablica: rais_download ---------------------------------------------

#' Baixa microdados da RAIS do repositório HuggingFace
#'
#' Baixa os arquivos `.7z` para um diretório local organizado por ano.
#' Arquivos já existentes no cache não são re-baixados (a menos que
#' `force = TRUE`).
#'
#' @param years integer vector. Anos desejados (ex: `2020:2023`).
#' @param type character. Tipo de dado: `"vinculos"`, `"estabelecimentos"` ou
#'   `"all"`. Default: `"vinculos"`.
#' @param state character vector ou NULL. UFs a baixar para o layout antigo
#' @param include_partial logical. Incluir anos parciais
#'   (ex: `"2023 Parcial"`)? Default: `FALSE`.
#'   (1985–2017). `NULL` baixa todas.
#'
#'   **Importante:** para o layout novo (2018+), o parâmetro `state` é
#'   **ignorado** porque os arquivos são distribuídos por **região
#'   geográfica**, não por UF. Nesse caso, o arquivo da região
#'   inteira é baixado e a filtragem por UF deve ser feita após a
#'   carga no banco:
#'
#'   ```r
#'   con <- rais_connect("rais.duckdb")
#'   tbl(con, "rais_novo") |> dplyr::filter(sigla_uf == 23L)  # 23 = CE
#'   ```
#'
#'   Regiões disponíveis (2018+): `NORDESTE`, `NORTE`, `SP`,
#'   `MG_ES_RJ`, `SUL`, `CENTRO_OESTE` (+ `NI` a partir de 2022).
#' @param include_estab logical. Baixar também os arquivos de estabelecimentos?
#'   Default: `FALSE`.
#' @param destdir character ou NULL. Diretório local para os arquivos.
#'   Default: `tempdir()`; para um cache persistente use
#'   `options(datarais.cache_dir = tools::R_user_dir("datarais", "cache"))`.
#' @param force logical. Re-baixa mesmo se já existir no cache. Default: `FALSE`.
#' @param timeout integer. Timeout por arquivo em segundos. Default: `300`.
#' @param workers integer. Downloads em paralelo. Default: `1` (sequencial); aumente via `workers` ou `options(datarais.workers = N)`.
#'   Controlado via `options(datarais.workers = N)`.
#'
#' @return invisível: tibble com `arquivo`, `ano`, `type`, `scope` e `status`.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   # Vínculos de 2022 e 2023
#'   rais_download(years = 2022:2023)
#'
#'   # Só UFs do Nordeste, 2015
#'   rais_download(
#'     years = 2015,
#'     state = c("CE", "RN", "PB", "PE", "AL", "SE", "BA", "PI", "MA")
#'   )
#' }
#' }
#'
#' @seealso [rais_load()] para pipeline completo.
#' @seealso [rais_available()] para listar anos disponíveis.
#' @export
rais_download <- function(years,
                           type            = "vinculos",
                           state           = NULL,
                           include_estab   = FALSE,
                           include_partial = FALSE,
                           destdir         = NULL,
                           force           = FALSE,
                           timeout         = 300,
                           workers         = getOption("datarais.workers", .default_workers())) {
  years  <- .validate_years(years)
  state  <- .validate_states(state)
  type   <- match.arg(type, c("vinculos", "estabelecimentos", "all"))
  cache  <- .cache_dir(destdir)
  tasks  <- .build_tasks_rais(years, type, state, include_estab, include_partial)
  n      <- nrow(tasks)
  workers <- max(1L, min(if (is.na(workers)) 3L else as.integer(workers), n))

  if (n == 0L) {
    cli::cli_inform(.tr("No valid year/file to download."))
    return(invisible(tibble::tibble()))
  }

  cli::cli_h1(.tr("Download RAIS Microdata"))
  cli::cli_inform(c(
    "i" = .tr("%d file(s) to process", n),
    "i" = paste0("Source: ", .HF_BASE),
    "i" = .tr("Cache: {.path %s}", cache),
    "i" = .tr("Workers: %d", workers)
  ))

  result <- .run_downloads(tasks, cache, force, timeout, workers)

  resumo <- dplyr::count(result, status)
  cli::cli_h2(.tr("Summary"))
  purrr::walk2(resumo$status, resumo$n, function(s, cnt) {
    icon <- switch(s, # nolint: object_usage_linter.
      baixado        = cli::col_green("v"),
      cache          = cli::col_blue("o"),
      nao_encontrado = cli::col_yellow("!"),
      erro           = cli::col_red("x"),
      "?"
    )
    cli::cli_inform("{icon} {s}: {cnt}")
  })

  invisible(result)
}

# -- Download de Layouts -------------------------------------------------------

#' Baixa os layouts (dicionários de variáveis) da RAIS
#'
#' Lista os arquivos `.xls`/`.xlsx` de layout disponíveis no HuggingFace
#' e baixa para o cache local.
#'
#' @param type character. `"vinculos"`, `"estabelecimentos"` ou `"ambos"`.
#'   Default: `"ambos"`.
#' @param destdir character ou NULL. Diretório local.
#' @param force logical. Re-baixa mesmo se já no cache. Default: `FALSE`.
#' @param timeout integer. Timeout por arquivo. Default: `120`.
#' @param verbose logical. Default: `TRUE`.
#'
#' @return invisível: tibble com `tipo`, `arquivo`, `destino` e `status`.
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   rais_download_layouts()
#'   rais_download_layouts(type = "vinculos")
#' }
#' }
#'
#' @export
rais_download_layouts <- function(type    = "ambos",
                                   destdir = NULL,
                                   force   = FALSE,
                                   timeout = 120,
                                   verbose = TRUE) {
  type  <- match.arg(type, c("vinculos", "estabelecimentos", "ambos"))
  cache <- file.path(.cache_dir(destdir), "layouts")
  if (!dir.exists(cache)) dir.create(cache, recursive = TRUE)

  subpastas <- c(
    vinculos         = "RAIS/Layouts/v\u00ednculos",
    estabelecimentos = "RAIS/Layouts/estabelecimento"
  )
    bases <- if (type == "ambos") c("vinculos", "estabelecimentos") else type

  if (verbose) {
    cli::cli_h1(.tr("Download RAIS layouts"))
    cli::cli_inform(.tr("Cache: {.path %s}", cache))
  }

  resultados <- purrr::map(bases, function(b) {
    if (verbose) cli::cli_h2(.tr("Listing - %s", b))

    tarefas <- .list_layout_urls(subpastas[[b]], timeout)
    if (nrow(tarefas) == 0L) {
      if (verbose) cli::cli_warn(.tr("No layout found in {.url %s}.", subpastas[[b]]))
      return(tibble::tibble())
    }

    n     <- nrow(tarefas)
    bloco <- vector("list", n)
    if (verbose)
      cli::cli_progress_bar(
        name   = paste(.tr("Downloading"), b),
        total  = n,
        format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total}"
      )

    for (i in seq_len(n)) {
      destfile <- file.path(cache, b, tarefas$arquivo[i])
      if (!dir.exists(dirname(destfile)))
        dir.create(dirname(destfile), recursive = TRUE)

      status <- if (.is_cached(destfile) && !force) {
        "cache"
      } else {
        res <- .download_file(tarefas$url[[i]], destfile, timeout)
        if (is.null(res)) "nao_encontrado"
        else if (.is_cached(destfile)) "baixado"
        else "erro"
      }

      bloco[[i]] <- tibble::tibble(
        tipo    = b,
        arquivo = tarefas$arquivo[i],
        destino = destfile,
        status  = status
      )
      if (verbose) cli::cli_progress_update()
    }
    if (verbose) cli::cli_progress_done()
    dplyr::bind_rows(bloco)
  }) |> dplyr::bind_rows()

  invisible(resultados)
}

#' Lista layouts .xls/.xlsx em uma pasta do HuggingFace
#' @noRd
.list_layout_urls <- function(hf_pasta, timeout = 15) {
  # Layouts no HuggingFace: listar via API
  itens <- .hf_list_dir(hf_pasta, timeout)
  if (is.null(itens) || length(itens) == 0L) {
    return(tibble::tibble(arquivo = character(), url = list()))
  }
  nomes <- itens[grepl("\\.(xlsx?|xls)$", itens, ignore.case = TRUE)]
  if (length(nomes) == 0L) {
    return(tibble::tibble(arquivo = character(), url = list()))
  }
  base <- paste0(
    .HF_BASE, "/",
    utils::URLencode(hf_pasta, repeated = TRUE), "/"
  )
  tibble::tibble(
    arquivo = nomes,
    url     = lapply(nomes, function(nm) {
      paste0(base, utils::URLencode(nm, repeated = TRUE))
    })
  )
}

#' Verifica se uma pasta de ano existe no HF (retorna nome ou NA)
#' @noRd
.hf_ano_existe <- function(pasta, timeout = 5) {
  url <- paste0(.HF_API, "/", utils::URLencode(
    paste0(.HF_PASTA_RAIS, "/", pasta), repeated = TRUE
  ))
  ok <- tryCatch({
    r <- httr2::request(url) |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = \(x) FALSE) |>
      httr2::req_perform()
    httr2::resp_status(r) == 200L
  }, error = function(e) FALSE)
  if (ok) pasta else NA_character_
}


# Default number of parallel workers: 1 (sequential), as required by the CRAN
# policy of a default below 2 cores. Users can raise it with the `workers`
# argument or options(datarais.workers = N).
.default_workers <- function() 1L
