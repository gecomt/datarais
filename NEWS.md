# datarais (development version)

## 0.1.0

* Versão inicial do pacote.
* Suporte a vínculos (1985–2024), estabelecimentos e trabalho doméstico.
* Download via HuggingFace (`alexsandroprado/rais`).
* Ingestão em DuckDB local com schema canônico tipado.
* Normalização automática de nomes de variáveis para snake_case PT.
* Layouts históricos suportados: 1985–1993, 1994–2014, 2015, 2016, 2017, 2018–2019, 2020+.
* Internacionalização PT/EN com detecção automática de locale.
* Exportação nativa para Parquet via `rais_to_parquet()`.
* Atualização incremental via `rais_update()`.
