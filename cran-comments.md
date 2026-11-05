## Test environments
* Windows 11 x64, R 4.6.1 (local)
* win-builder: R-devel (via devtools::check_win_devel())
* Ubuntu 22.04, R-release (GitHub Actions)
* macOS latest, R-release (GitHub Actions)

## R CMD check results
0 errors | 0 warnings | 1 note

* NOTE: "New submission" (first release of this package).

## Notes on first submission
* This is a first submission to CRAN.
* The package downloads data from the HuggingFace repository
  <https://huggingface.co/datasets/alexsandroprado/rais>.
  All downloads are user-initiated, no automatic downloads occur on
  package load or at build time.
* 7-Zip is required as a system dependency only for pre-2020 RAIS files
  (PPMd compression). Files from 2020 onwards use LZMA and work without
  any external tools. This is documented in SystemRequirements and the
  README.
* Tests that require internet access are protected with
  skip_if_offline() and skip_if() guards, and are skipped on CRAN and when the
  HuggingFace repository is not reachable or not populated.
* The package includes a vignette that requires internet access to run.
  All examples are wrapped in \dontrun{} or \donttest{} accordingly.
