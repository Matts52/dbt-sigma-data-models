# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

dbt-sigma-data-models composes [Sigma data models](https://help.sigmacomputing.com/docs/manage-data-models-as-code) from dbt macros instead of hand-writing the Sigma JSON spec. The compiled spec is attached to a dbt model's `meta` config via `sigma_data_models.materialize()`, so it lands in `manifest.json` on `dbt parse`/`dbt compile`. The macros never touch Sigma's API — this is compile-time JSON composition, and never needs a warehouse connection *unless* a table's `columns` are left off `sigma_data_models.table()` (auto-population via `adapter.get_columns_in_relation`).

The compiled shape is meant to be structurally faithful to Sigma's own [data model representation examples](https://help.sigmacomputing.com/docs/data-model-representation-example-library) - `pages[].elements[]`, `source.path`, `{id, formula}` columns, relationships nested under their source table, etc. - not an independently-invented shape. See [Coverage](README.md#coverage) in the README for what's modeled vs. not.

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
dbt run-operation assert_sigma_spec --profile sigma_integration_tests_duckdb
```

Since the demo model always passes explicit `columns`, `dbt parse` alone is enough to verify it compiles without a connection - no adapter-specific SQL is involved on that path. The column auto-population path (`columns` left off `sigma_data_models.table()`) requires `execute=True`, so it's only exercised via `dbt run-operation` (see `assert_sigma_spec`'s auto-population check), never by the demo model itself - adding it there would break the connection-free `dbt parse` step for the whole project. `assert_sigma_spec` (in `integration_tests/macros/assert_sigma_spec.sql`) is the real correctness check: it asserts the composed spec's *shape* (field names, nesting, which fields are present/omitted) matches Sigma's documented examples, not just that compilation doesn't error. See `integration_tests/README.md` for which specific Sigma example each assertion corresponds to.

## Architecture

### Core Macros (`macros/sigma/`)
- `model`: assembles `tables` into a single page, resolves `relationships` into their real nested shape (only possible once every table's real element/column ids exist), strips internal-only fields
- `table`: a Sigma table element bound to a warehouse relation; freezes ids for itself and its columns/metrics/folders/filters off `key ~ '@' ~ database.schema.identifier` (`freeze_scope`) - both, not just the identifier, so a self-join (same physical table bound twice under different keys) gets distinct ids per occurrence instead of colliding (this was a real bug, fixed after the initial identifier-only design)
- `column` / `metric` / `relationship` / `folder` / `filter`: normalize inputs into intent descriptors (bare strings/dicts/tuples where possible); `table`/`model` resolve them into Sigma's real field names, since that needs table-level context these macros don't have
- `materialize`: wires the composed spec into `config(meta={'sigma_data_model': spec})`
- `freeze_id`: `local_md5(path)` over a stable path — guarantees compile-time determinism, not Sigma-side id permanence
- `titleize`: default display-name derivation (`snake_case` -> `Title Case`)

See `macros/schema.yml` for full macro-level argument docs, and `README.md` for usage.

### A key implementation detail: internal-only fields
`table()` returns `key` and `_column_ids` on each table dict *in addition to* the real Sigma fields - `model()` needs both to resolve `relationships`/`folders` (which reference tables/columns by name, not by their frozen id) before stripping them from the final emitted elements. Any field prefixed `_`, plus the bare `key` field, is treated as internal and never reaches `config.meta.sigma_data_model`.

One Jinja gotcha this ran into: field names that collide with Python dict methods (`items`, `keys`, `values`) can't be accessed via dot-notation on a dict whose data happens to include those field names - Jinja's attribute lookup finds the built-in method first. Use bracket notation (`relationship['keys']`, `filter['values']`) when a field name might collide. This is also why `sigma_data_models.filter()`'s `options` param is a plain dict rather than `**kwargs` - dbt's Jinja parser doesn't support `**kwargs` in macro definitions.

### Integration Tests (`integration_tests/`)
- Uses local package reference (`packages.yml: local: ../`)
- Seeds (`accounts`, `employees`) + staging models + one `sigma_*` model exercising every supported shape + a companion `exposures.yml` entry
- `integration_tests/macros/assert_sigma_spec.sql`: shape assertions (run via `dbt run-operation`) plus a set of `assert_*_rejected` macros that are expected to raise a compiler error - the test script (`scripts/run_integration_tests_duckdb.sh`) treats a zero exit from those as a regression
- Two profile targets in `integration_tests/profiles.yml`: `sigma_integration_tests_duckdb` (default, used by the test script) and `sigma_integration_tests_snowflake` (dummy credentials, documents the adapter this package targets in production)

## dbt Version Requirements
- Requires dbt >= 1.6.0 and < 2.0.0
