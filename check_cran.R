# ══════════════════════════════════════════════════════════════════════════════
# check_cran.R \u2014 Pipeline completo de verifica\u00e7\u00e3o antes de submeter ao CRAN
# Uso: source("check_cran.R")
# ══════════════════════════════════════════════════════════════════════════════

cli::cli_h1("datarais \u2014 CRAN Submission Check")
start_time <- proc.time()

ok    <- character()
warn  <- character()
fail  <- character()
notes <- character()

run_step <- function(label, expr, optional = FALSE) {
  cli::cli_h2(label)
  result <- tryCatch({
    force(expr)
    ok <<- c(ok, label)
    cli::cli_alert_success(label)
    invisible(TRUE)
  }, warning = function(w) {
    warn <<- c(warn, paste0(label, ": ", conditionMessage(w)))
    cli::cli_alert_warning(paste("WARNING:", conditionMessage(w)))
    invisible(FALSE)
  }, error = function(e) {
    if (optional) {
      notes <<- c(notes, paste0(label, " [opcional]: ", conditionMessage(e)))
      cli::cli_alert_info(paste("SKIPPED (optional):", conditionMessage(e)))
    } else {
      fail <<- c(fail, paste0(label, ": ", conditionMessage(e)))
      cli::cli_alert_danger(paste("FAILED:", conditionMessage(e)))
    }
    invisible(FALSE)
  })
}

# ── 0. Depend\u00eancias necess\u00e1rias ───────────────────────────────────────────────
needed <- c("devtools","rcmdcheck","spelling","urlchecker",
            "covr","rhub","pkgdown","lintr","styler")
missing_pkgs <- needed[!vapply(needed, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
  cli::cli_alert_warning(
    "Instalando depend\u00eancias faltando: {paste(missing_pkgs, collapse=', ')}"
  )
  install.packages(missing_pkgs, quiet = TRUE)
}

# ── 1. Documenta\u00e7\u00e3o ───────────────────────────────────────────────────────────
run_step("1. devtools::document()", {
  devtools::document()
})

# ── 2. Estilo ─────────────────────────────────────────────────────────────────
run_step("2. styler::style_pkg()", {
  result <- styler::style_pkg()
  changed <- sum(result$changed, na.rm = TRUE)
  if (changed > 0)
    warning(paste(changed, "arquivo(s) alterado(s) pelo styler \u2014 revise antes de submeter"))
})

run_step("3. lintr::lint_package()", {
  lints <- lintr::lint_package()
  n <- length(lints)
  if (n > 0) warning(paste(n, "lint(s) encontrado(s)"))
}, optional = TRUE)

# ── 3. Testes ─────────────────────────────────────────────────────────────────
run_step("4. devtools::test()", {
  result <- devtools::test()
  failed <- sum(as.data.frame(result)$failed, na.rm = TRUE)
  if (failed > 0) stop(paste(failed, "teste(s) falhando"))
})

run_step("5. covr::package_coverage()", {
  cov    <- covr::package_coverage(quiet = TRUE)
  pct    <- covr::percent_coverage(cov)
  msg    <- sprintf("Cobertura de testes: %.1f%%", pct)
  if (pct < 50) warning(paste(msg, "\u2014 recomendado > 70% para CRAN"))
  else cli::cli_inform(msg)
}, optional = TRUE)

# ── 4. Exemplos ───────────────────────────────────────────────────────────────
run_step("6. devtools::run_examples()", {
  devtools::run_examples(run_donttest = FALSE)
})

# ── 5. Qualidade da documenta\u00e7\u00e3o ──────────────────────────────────────────────
run_step("7. spelling::spell_check_package()", {
  erros <- spelling::spell_check_package()
  if (nrow(erros) > 0) {
    warning(paste(nrow(erros), "poss\u00edvel(eis) erro(s) de ortografia:",
                  paste(erros$word[seq_len(min(5, nrow(erros)))], collapse = ", ")))
  }
}, optional = TRUE)

run_step("8. urlchecker::url_check()", {
  result <- urlchecker::url_check()
  if (!is.null(result) && nrow(result) > 0)
    warning(paste(nrow(result), "URL(s) com problema"))
}, optional = TRUE)

# ── 6. Check padr\u00e3o CRAN ──────────────────────────────────────────────────────
run_step("9. rcmdcheck --as-cran", {
  result <- rcmdcheck::rcmdcheck(
    args     = c("--as-cran", "--no-manual"),
    error_on = "warning"
  )
  if (length(result$errors)   > 0) stop(paste(result$errors,   collapse = "\n"))
  if (length(result$warnings) > 0) stop(paste(result$warnings, collapse = "\n"))
  n_notes <- length(result$notes)
  if (n_notes > 1) warning(paste(n_notes, "notes \u2014 verifique se s\u00e3o aceit\u00e1veis"))
})

# ── 7. Check multiplataforma ──────────────────────────────────────────────────
run_step("10. devtools::check_win_devel()", {
  devtools::check_win_devel()
  cli::cli_inform("Aguarde e-mail com resultado do win-builder")
}, optional = TRUE)

run_step("11. devtools::check_win_release()", {
  devtools::check_win_release()
}, optional = TRUE)

run_step("12. rhub::check_for_cran()", {
  rhub::check_for_cran()
  cli::cli_inform("Aguarde e-mail com resultado do rhub")
}, optional = TRUE)

# ── 8. Site pkgdown (opcional) ────────────────────────────────────────────────
run_step("13. pkgdown::build_site()", {
  pkgdown::build_site(preview = FALSE)
}, optional = TRUE)

# ══ Resumo ═══════════════════════════════════════════════════════════════════
elapsed <- round((proc.time() - start_time)["elapsed"] / 60, 1)
cli::cli_h1("Resultado Final")
cli::cli_inform(c(
  "v" = paste0("OK       : ", length(ok)),
  "!" = paste0("Warnings : ", length(warn)),
  "x" = paste0("Falhas   : ", length(fail)),
  "i" = paste0("Opcionais: ", length(notes)),
  "i" = paste0("Tempo    : ", elapsed, " min")
))

if (length(fail) > 0) {
  cli::cli_h2("Falhas")
  for (f in fail) cli::cli_alert_danger(f)
}
if (length(warn) > 0) {
  cli::cli_h2("Avisos")
  for (w in warn) cli::cli_alert_warning(w)
}

if (length(fail) == 0 && length(warn) == 0) {
  cli::cli_alert_success("Pacote pronto para submeter ao CRAN!")
  cli::cli_inform(c("i" = "Pr\u00f3ximo passo: devtools::release()"))
} else if (length(fail) == 0) {
  cli::cli_alert_warning("Warnings encontrados \u2014 revise antes de submeter")
} else {
  cli::cli_alert_danger("Corrija as falhas antes de submeter ao CRAN")
}

# ── 9b. Checks opcionais adicionais ──────────────────────────────────────────

run_step("14. devtools::check_mac_release()", {
  devtools::check_mac_release()
  cli::cli_inform("Aguarde e-mail com resultado (macOS + R-release)")
}, optional = TRUE)

run_step("15. devtools::check_mac_devel()", {
  devtools::check_mac_devel()
  cli::cli_inform("Aguarde e-mail com resultado (macOS + R-devel)")
}, optional = TRUE)

run_step("16. goodpractice::gp()", {
  gp <- goodpractice::gp()
  fails <- goodpractice::failed_checks(gp)
  if (length(fails) > 0)
    warning(paste(length(fails), "boas pr\u00e1ticas falhando:", paste(fails[1:3], collapse = ", ")))
}, optional = TRUE)

run_step("17. available::available('datarais')", {
  available::available("datarais", browse = FALSE)
}, optional = TRUE)

run_step("18. desc::desc_normalize()", {
  desc::desc_normalize()
  cli::cli_alert_success("DESCRIPTION normalizado")
}, optional = TRUE)

run_step("19. devtools::build(vignettes = TRUE)", {
  built <- devtools::build(vignettes = TRUE, quiet = TRUE)
  size  <- file.size(built) / 1024 / 1024
  if (size > 5)
    warning(sprintf("Tarball grande: %.1f MB (CRAN recomenda < 5 MB)", size))
  else
    cli::cli_inform(sprintf("Tarball: %.1f MB \u2713", size))
}, optional = TRUE)

run_step("20. pkgstats::pkgstats()", {
  s <- pkgstats::pkgstats()
  cli::cli_inform(c(
    "i" = paste("Linhas de c\u00f3digo R:", s$loc_R),
    "i" = paste("Fun\u00e7\u00f5es exportadas:", s$num_exported_fns),
    "i" = paste("Fun\u00e7\u00f5es internas  :", s$num_internal_fns)
  ))
}, optional = TRUE)

run_step("21. codemetar::write_codemeta()", {
  codemetar::write_codemeta()
  cli::cli_alert_success("codemeta.json gerado")
}, optional = TRUE)

# P\u00f3s-publica\u00e7\u00e3o (s\u00f3 roda se o pacote j\u00e1 estiver no CRAN)
run_step("22. foghorn::cran_results('datarais') [p\u00f3s-CRAN]", {
  res <- foghorn::cran_results("datarais")
  print(res)
}, optional = TRUE)
