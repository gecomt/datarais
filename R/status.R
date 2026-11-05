# status.R
# Verifica disponibilidade do reposit\u00f3rio HuggingFace da RAIS

#' Verifica se o repositório HuggingFace da RAIS está acessível
#'
#' Faz uma requisição leve à API do HuggingFace e retorna o status.
#' Útil para diagnosticar problemas de conectividade antes de iniciar
#' um download com `rais_load()` ou `rais_download()`.
#'
#' @param timeout integer. Timeout em segundos. Default: `10`.
#' @param verbose logical. Se `TRUE`, exibe mensagem detalhada. Default: `TRUE`.
#'
#' @return invisível: lista com `online` (logical), `latencia_ms` (numeric),
#'   `url` (character) e `mensagem` (character).
#'
#' @examples
#' \donttest{
#' if (interactive()) {
#'   rais_status()
#'
#'   # Só verificar sem imprimir
#'   st <- rais_status(verbose = FALSE)
#'   st$online
#' }
#' }
#'
#' @seealso [rais_available()] para listar anos disponíveis.
#' @export
rais_status <- function(timeout = 10, verbose = TRUE) {
  url_teste <- .HF_API
  inicio    <- proc.time()["elapsed"]

  ok <- tryCatch({
    resp <- httr2::request(url_teste) |>
      httr2::req_timeout(timeout) |>
      httr2::req_error(is_error = \(r) FALSE) |>
      httr2::req_perform()
    httr2::resp_status(resp) == 200L
  }, error = function(e) FALSE)

  latencia_ms <- round((proc.time()["elapsed"] - inicio) * 1000)

  resultado <- list(
    online      = ok,
    latencia_ms = latencia_ms,
    url         = url_teste,
    mensagem    = if (ok) {
      paste0("HuggingFace online (", latencia_ms, " ms)")
    } else {
      "HuggingFace repository unavailable"
    }
  )

  if (verbose) {
    repo_url <- paste0("https://huggingface.co/datasets/", .HF_REPO)
    if (ok) {
      cli::cli_inform(c(
        "v" = .tr("HuggingFace repository %s", cli::col_green("online")),
        "i" = .tr("Latency: %d ms", latencia_ms),
        "i" = .tr("Dataset: {.url %s}", repo_url)
      ))
    } else {
      cli::cli_inform(c(
        "x" = .tr("HuggingFace repository %s",
                   cli::col_red("unavailable")),
        "i" = .tr("Tested: {.url %s}", url_teste),
        "i" = .tr("Check your connection or try again later.")
      ))
    }
  }

  invisible(resultado)
}
