# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dbt-sigma-data-models composes [Sigma data models](https://help.sigmacomputing.com/docs/manage-data-models-as-code) from dbt macros instead of hand-writing the Sigma JSON/YAML spec. The compiled spec is attached to a dbt model's `meta` config via `sigma_data_models.materialize()`, so it lands in `manifest.json` on `dbt parse`/`dbt compile`. The macros never touch the underlying tables — a warehouse connection is only needed if a table's `columns` are left off `sigma_data_models.table()` (auto-population via `adapter.get_columns_in_relation`).

## Key Commands

### Running Integration Tests
```bash
./scripts/run_integration_tests_duckdb.sh
```

### Manual Test Steps
```bash
cd integration_tests
dbt deps --profile sigma_integration_tests_duckdb
dbt seed --profile sigma_integration_tests_duckdb
dbt run --profile sigma_integration_tests_duckdb
dbt parse --profile sigma_integration_tests_duckdb --no-partial-parse
```

Since `sigma`'s macros are compile-time only (no adapter-specific SQL beyond `adapter.get_columns_in_relation`), `dbt parse` alone is enough to verify a spec compiles when a table's `columns` are explicit. The integration test's demo model (`sigma_territory_carving_demo.sql`) does exactly that, so it also parses cleanly with no connection at all.

## Architecture

### Core Macros (`macros/sigma/`)
- `model`: top-level Sigma data model — composes `tables` and `relationships`
- `table`: a Sigma table; freezes element ids for itself and its columns/metrics, can auto-populate columns from the live warehouse relation
- `column` / `metric` / `relationship`: per-element specs, each usable as bare strings/dicts/tuples unless an override is needed
- `materialize`: wires the composed spec into `config(meta={'sigma_data_model': spec})`
- `freeze_id`: `local_md5(path)` over a path built from stable authoring keys — guarantees compile-time determinism, not Sigma-side id permanence
- `titleize`: default display-name derivation (`snake_case` -> `Title Case`)

See `macros/schema.yml` for full macro-level argument docs, and `README.md` for usage.

### Integration Tests (`integration_tests/`)
- Uses local package reference (`packages.yml: local: ../`)
- Seeds (`accounts`, `employees`) + staging models + one `sigma_*` model + a companion `exposures.yml` entry
- Two profile targets in `integration_tests/profiles.yml`: `sigma_integration_tests_duckdb` (default, used by the test script) and `sigma_integration_tests_snowflake` (dummy credentials, documents the adapter this package targets in production)

## dbt Version Requirements
- Requires dbt >= 1.6.0 and < 2.0.0
