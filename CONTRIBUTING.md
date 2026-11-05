# Contribuindo com o datarais

Obrigado pelo interesse em contribuir! Este documento descreve o processo.

## Reportando bugs

Use o [template de bug report](.github/ISSUE_TEMPLATE/bug_report.md) e inclua:
- Versão do R (`R.version`) e do pacote (`packageVersion("datarais")`)
- Sistema operacional
- Código mínimo para reproduzir o problema

## Sugerindo funcionalidades

Use o [template de feature request](.github/ISSUE_TEMPLATE/feature_request.md).

## Pull Requests

1. Faça um fork do repositório
2. Crie um branch: `git checkout -b feat/minha-funcionalidade`
3. Faça suas alterações e rode:

```r
devtools::document()   # regenera NAMESPACE e Rd
styler::style_pkg()    # formata o código
devtools::check()      # deve passar sem erros
```

4. Atualize `NEWS.md` com um resumo da mudança
5. Abra uma PR usando o template

## Estrutura do pacote

```
R/
  rais.R         # constantes, validações, .onAttach
  catalog.R      # rais_available(), rais_available_years()
  status.R       # rais_status()
  download.R     # rais_download(), rais_download_layouts()
  parse.R        # rais_parse(), rais_parse_batch()
  database.R     # rais_connect(), rais_load(), rais_update(),
                 # rais_to_duckdb(), rais_to_parquet(), rais_info()
  rename.R       # rais_rename_cols(), rais_col_dictionary()
  normalize.R    # .normalize_pipeline(), .dedup_names()
  schema.R       # schema canônico das tabelas DuckDB
  layouts.R      # períodos de layout, rais_layouts()
  i18n.R         # .tr(), rais_set_language(), rais_language()
  data.R         # documentação de uf_codigos
```

## Convenções

- **Idioma do código**: inglês
- **Nomes de funções públicas**: `rais_*` em snake_case
- **Mensagens ao usuário**: via `cli`, nunca `message()` ou `stop()` direto
- **Internacionalização**: toda string de usuário passa por `.tr()`
- **Nomes de colunas**: snake_case em português (conforme documentação oficial da RAIS)
- **Encoding**: arquivos `.R` em UTF-8; strings não-ASCII em código usam `\uXXXX`
