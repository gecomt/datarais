# datarais

<!-- badges: start -->
[![R-CMD-check](https://github.com/alexsandroprado/datarais/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/alexsandroprado/datarais/actions/workflows/R-CMD-check.yaml)
[![Codecov test coverage](https://codecov.io/gh/alexsandroprado/datarais/branch/main/graph/badge.svg)](https://app.codecov.io/gh/alexsandroprado/datarais?branch=main)
[![CRAN status](https://www.r-pkg.org/badges/version/datarais)](https://CRAN.R-project.org/package=datarais)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

*Leia em [Portugues](README.pt-BR.md)*

---

**datarais** provides access to the Brazilian Annual Social Information
Report (*Relacao Anual de Informacoes Sociais*, RAIS) microdata directly
from R. The package covers formal employment records (1985-2025),
establishments, and domestic work, downloaded from the
[HuggingFace repository](https://huggingface.co/datasets/alexsandroprado/rais/tree/main/RAIS)
and stored in a local [DuckDB](https://duckdb.org) database for fast
SQL and `dplyr` queries, even at tens-of-gigabytes scale.

Column names are automatically normalised to **snake\_case Portuguese**,
consistent across all historical layouts and years.

## System requirements

- R >= 4.1.0
- [7-Zip](https://www.7-zip.org/download.html), required for pre-2020
  RAIS files (PPMd compression). Not required for 2020+ files (LZMA).

## Installation

```r
# CRAN
install.packages("datarais")

# Development version
pak::pak("alexsandroprado/datarais")
```

## Hardware requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 8 GB | 16 GB |
| Free disk | 20 GB per year | SSD with 100+ GB |
| Internet | Stable broadband | 50 Mbps or faster |

Approximate disk usage per year of data:

| Data | Compressed (.7z) | DuckDB |
|------|-----------------|--------|
| Employment records, 1 year (2020+) | 2-3 GB | 8-15 GB |
| Employment records, 1 year (pre-2018, by state) | 1-2 GB | 5-10 GB |
| Establishments, 1 year | 200-500 MB | 1-3 GB |
| Full series (1985-2025) | 80-120 GB | 300-500 GB |

## Quick start

```r
library(datarais)
library(dplyr)

# Check repository availability
rais_status()

# Download, parse and load into DuckDB in one step
rais_load(
  years   = 2022:2023,
  type    = "vinculos",
  db_path = "rais.duckdb"
)

# Query with dplyr
con <- rais_connect("rais.duckdb")

tbl(con, "rais_novo") |>
  filter(ano == 2023) |>
  group_by(sigla_uf) |>
  summarise(
    n_jobs       = n(),
    avg_wage_brl = mean(vl_remun_media_nom, na.rm = TRUE)
  ) |>
  arrange(desc(avg_wage_brl)) |>
  collect()

DBI::dbDisconnect(con, shutdown = TRUE)
```

## Selecting data type

```r
# Employment records only (default)
rais_load(years = 2022, type = "vinculos",         db_path = "rais.duckdb")

# Establishments only
rais_load(years = 2022, type = "estabelecimentos", db_path = "rais.duckdb")

# Both
rais_load(years = 2022, type = "all",              db_path = "rais.duckdb")
```

## Downloading by state (UF)

The `state` parameter behaves differently depending on the period.

**Pre-2018 (legacy layout):** files are distributed by state, so
`state` works directly:

```r
rais_load(years = 2010, state = c("CE", "RN", "PB"), db_path = "rais.duckdb")
```

**2018 and later (new layout):** files are distributed by geographic
region, so `state` is **ignored**. The entire region file is downloaded;
filter by state after loading:

```r
rais_load(years = 2022, db_path = "rais.duckdb")

con <- rais_connect("rais.duckdb")
tbl(con, "rais_novo") |> filter(sigla_uf == 23L)  # 23 = Ceara
```

| File (2018+) | States included |
|---|---|
| `RAIS_VINC_PUB_NORDESTE.7z` | CE RN PB PE AL SE BA PI MA |
| `RAIS_VINC_PUB_NORTE.7z` | AM PA AC RO RR AP TO |
| `RAIS_VINC_PUB_SP.7z` | SP |
| `RAIS_VINC_PUB_MG_ES_RJ.7z` | MG ES RJ |
| `RAIS_VINC_PUB_SUL.7z` | PR SC RS |
| `RAIS_VINC_PUB_CENTRO_OESTE.7z` | MS MT GO DF |

## Tables in DuckDB

All files live under `RAIS/<year>/` in the HuggingFace repository.
The distinction between old and new layout is made by the file names
inside each year folder, not by separate folders.

| Table | Content | Period | Source file |
|---|---|---|---|
| `rais_antigo` | Employment records by state | 1985-2017 | `RAIS/<year>/<UF><year>.7z` |
| `rais_novo` | Employment records by region | 2018+ | `RAIS/<year>/RAIS_VINC_PUB_<region>.7z` |
| `rais_estab` | Establishments | 1985+ | `RAIS/<year>/ESTB<year>.7z` or `RAIS_ESTAB_PUB.7z` |

## Key variables

| Variable | Description |
|---|---|
| `sigla_uf` | IBGE state code (e.g. 23 = CE) |
| `id_municipio` | IBGE municipality code |
| `ano` | Reference year |
| `vl_remun_media_nom` | Average nominal wage (BRL) |
| `vl_remun_media_sm` | Average wage in minimum wages |
| `qtd_horas_contratadas` | Weekly contracted hours |
| `cnae20_subclasse` | CNAE 2.0 subclass (from 2006) |
| `cbo_2002` | CBO Occupation 2002 (from 2003) |
| `tipo_vinculo` | Type of employment contract |
| `grau_instrucao` | Education level |
| `raca_cor` | Race/colour (from 1999) |

View the full variable dictionary:

```r
rais_col_info()
rais_col_info(search = "remun")
```

## Historical layouts

```r
rais_layouts()
```

| Period | Format | Encoding | Compression |
|---|---|---|---|
| 1985-2017 | By state | latin1 | PPMd (requires 7-Zip) |
| 2018-2019 | By region | UTF-8 | PPMd (requires 7-Zip) |
| 2020+ | By region | UTF-8 | LZMA |

## Incremental update

```r
# Downloads only years not yet in the database
rais_update(db_path = "rais.duckdb")

# Include partial-year releases (e.g. "2024 Parcial")
rais_update(db_path = "rais.duckdb", include_partial = TRUE)
```

## Export to Parquet

```r
rais_to_parquet(
  db_path      = "rais.duckdb",
  output_dir   = "parquet/",
  partition_by = "sigla_uf"
)
```

## Convenience functions

```r
# Shortcut to dplyr::tbl() -- auto-selects the right table
con <- rais_connect("rais.duckdb")
rais_tbl(con, year = 2022)                  # rais_novo, filtered to 2022
rais_tbl(con, type = "estabelecimentos")    # rais_estab
rais_tbl(con, table = "rais_antigo")        # explicit name

# List available files on HuggingFace
rais_hf_files(years = 2023)
rais_hf_files(years = 2023, type = "vinculos")

# Download variable layout files (.xls/.xlsx)
rais_download_layouts(type = "vinculos", destdir = "layouts/")
```

## Language support

Messages are displayed in English by default and switch automatically
to Brazilian Portuguese when the OS locale is `pt_BR`:

```r
rais_set_language("pt")   # switch to Portuguese
rais_set_language("en")   # switch to English
rais_set_language(NULL)   # restore OS locale detection
rais_language()           # show active language and source
```

The language can also be set via the environment variable
`RAIS_LANGUAGE=pt` before starting R.

## Reference data

```r
data(uf_codigos)
head(uf_codigos)
#>   sigla codigo       regiao
#> 1    RO     11        Norte
#> 2    AC     12        Norte
```

## Function reference

| Function | Description |
|---|---|
| `rais_load()` | Full pipeline: download, parse, and load into DuckDB |
| `rais_update()` | Incremental update (downloads new years only) |
| `rais_download()` | Download `.7z` files only |
| `rais_parse()` | Read and normalise a single `.7z` file |
| `rais_parse_batch()` | Read and normalise multiple files |
| `rais_connect()` | Open DuckDB connection |
| `rais_tbl()` | Lazy `tbl` reference to a RAIS table |
| `rais_to_duckdb()` | Write a data frame to the database |
| `rais_to_parquet()` | Export tables to Parquet |
| `rais_info()` | List tables and row counts in the database |
| `rais_available()` | List years available on HuggingFace |
| `rais_available_years()` | Integer vector of available years |
| `rais_hf_files()` | List individual files with sizes and URLs |
| `rais_status()` | Test connectivity to HuggingFace |
| `rais_rename_cols()` | Normalise column names |
| `rais_col_dictionary()` | Column name mapping dictionary |
| `rais_col_info()` | Column metadata (type, description, availability) |
| `rais_translate_cols()` | Translate a vector of column names |
| `rais_layouts()` | Summary of historical layouts |
| `rais_download_layouts()` | Download layout files from HuggingFace |
| `rais_set_language()` | Set display language (en/pt) |
| `rais_language()` | Show active language |

## Documentation

- Vignette (introduction): `vignette("datarais")`
- Vignette (historical series): `vignette("serie-historica")`
- Full reference: `help(package = "datarais")`
- Website: <https://alexsandroprado.github.io/datarais/>

## Cache and parallel downloads

By default, downloaded files are stored in a temporary directory and downloads run sequentially, in line with CRAN policy. To keep a persistent cache and download in parallel:

```r
options(
  datarais.cache_dir = tools::R_user_dir("datarais", "cache"),
  datarais.workers   = 3
)
```

## Citation

```r
citation("datarais")
```

```
Prado, A. (2025). datarais: Access to RAIS Microdata via HuggingFace and DuckDB.
R package version 0.1.0. https://github.com/alexsandroprado/datarais
```

## Contributing

Contributions are welcome. Please see
[`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines.
Report bugs via [Issues](https://github.com/alexsandroprado/datarais/issues).

## License

MIT (c) 2025 Alexsandro Prado
