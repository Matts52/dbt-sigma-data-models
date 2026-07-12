# Integration Tests

A runnable example package: seeds (`accounts`, `employees`) + staging models + one `sigma_*` model composed with `sigma_data_models.model()`/`sigma_data_models.table()` + a companion `exposures.yml` entry.

## Prerequisites

- DuckDB (no setup needed — the profile points at a local file) or a Snowflake account, depending on which target you run against
- `dbt deps` to install this package locally (`packages.yml` points at `../`)

## Running Tests

**Quick start:**
```bash
./scripts/run_integration_tests_duckdb.sh
```

**Manual steps:**
```bash
cd integration_tests
dbt deps --profile sigma_integration_tests_duckdb
dbt seed --profile sigma_integration_tests_duckdb
dbt run --profile sigma_integration_tests_duckdb
dbt parse --profile sigma_integration_tests_duckdb --no-partial-parse
```

`dbt parse` is the real check here: it confirms the composed Sigma spec lands at `manifest.json -> nodes -> model.sigma_integration_tests.sigma_territory_carving_demo -> config.meta.sigma_data_model`. `dbt seed`/`dbt run` exist to prove the model is still a valid, runnable dbt model — the macros themselves never touch the warehouse unless a table's `columns` are left off `sigma_data_models.table()`.

## What's Tested

1. **Spec composition** - `sigma_data_models.model()`/`sigma_data_models.table()`/`sigma_data_models.materialize()` compile a full Sigma data model into `config.meta.sigma_data_model`
2. **Frozen element ids** - table/column/metric ids are stable (`sigma_data_models.freeze_id()`) across recompiles
3. **Exposure lineage** - `exposures.yml` resolves upstream `ref()`s through the `sigma_*` model

## Switching Adapters

Two profile targets are defined in `profiles.yml`: `sigma_integration_tests_duckdb` (default, no credentials needed) and `sigma_integration_tests_snowflake` (dummy credentials — documents the adapter this package targets in production, since Sigma itself only connects to Snowflake). Pass `--profile` to pick one, or edit `profile:` in `dbt_project.yml` to change the default.
