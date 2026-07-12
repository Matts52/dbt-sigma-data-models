# Integration Tests

A runnable example package: seeds (`accounts`, `employees`) + staging models + one `sigma_*` model exercising every shape this package supports + a companion `exposures.yml` entry.

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
dbt run-operation assert_sigma_spec --profile sigma_integration_tests_duckdb
```

`dbt seed`/`dbt run` prove the model is still a valid, runnable dbt model — the macros themselves never touch the warehouse. `dbt parse` confirms the composed Sigma spec lands at `manifest.json -> nodes -> model.sigma_integration_tests.sigma_territory_carving_demo -> config.meta.sigma_data_model`. `assert_sigma_spec` is the real correctness check — it asserts the *shape* of that compiled spec (field names, nesting, which fields are present or correctly omitted), not just that compilation didn't error.

## Sigma examples this is checked against

`assert_sigma_spec` (in `macros/assert_sigma_spec.sql`) validates the composed spec against Sigma's own [data model representation example library](https://help.sigmacomputing.com/docs/data-model-representation-example-library):

| Shape | Sigma example | What's checked |
| --- | --- | --- |
| Top-level model / create request | [create-a-data-model-from-a-code-representation](https://help.sigmacomputing.com/docs/create-a-data-model-from-a-code-representation) | `name`/`folderId`/`schemaVersion`/`pages` present; `pages[0].id` is left `''` (Sigma-assigned, not authored) |
| Warehouse table element | [example: single table](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-single-table) | `{id, kind: "table", source: {connectionId, kind: "warehouse-table", path}, columns, order}`; no internal-only fields (`key`, `_column_ids`) leak into the emitted element |
| Passthrough column | [example: single table](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-single-table) | `{id, formula}` only — no `name` field; `formula` defaults to `'[identifier/Titleized Name]'` |
| Calculated column | [example: table + calculated column](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-table-and-a-calculated-column) | `{id, formula, name}` — `name` defaults to a title-cased key |
| Metric | [example: table + metric](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-table-and-a-metric) | `{id, formula, name}`; omitted entirely from a table with no metrics, not emitted as `[]` |
| Relationship | [example: table + relationship](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-table-and-a-relationship) | Nests under the *source* table's element (not the target's, and not at the model level) as `{id, targetElementId, keys: [{sourceColumnId, targetColumnId}], name}`; `targetElementId` and both column ids resolve to the real ids of the referenced table/columns |
| Folder | [example: folder](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-folder) | `{id, name, items}`, where `items` are the member columns' real ids |
| Filter | [example: filters](https://help.sigmacomputing.com/docs/example-representation-data-model-with-filters) | `{id, columnId, kind, ...}`, where `...` (e.g. `mode`/`values` for a `kind='list'` filter) is passed through verbatim; `columnId` resolves to the real id of the referenced column |
| Column/metric formatting fields | [format columns and metrics](https://help.sigmacomputing.com/docs/format-columns-and-metrics-in-the-code-representation-of-a-data-model) | Consulted to confirm this package's `{id, formula, name}` fields are a subset of the real schema (not just a look-alike); the `format` field itself isn't modeled — see the README's Coverage section |

Also referenced (and consciously *not* modeled — see the README's Coverage section) to make sure this package doesn't invent fields that don't exist in Sigma's real schema:

- [example: join](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-join) — confirmed joins are a distinct `source.kind: "join"` element from relationships, not the same concept
- [example: union](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-union) — confirmed unions are a distinct `source.kind: "union"` element combining multiple sources (warehouse tables or other elements) by matched columns
- [example: transposed table](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-transposed-table) — confirmed transposition is a distinct `source.kind: "transpose"` element, not a table property
- [example: grouping](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-grouping) — confirmed `groupings` (statistical `groupBy`) is distinct from `folders`
- [example: column-level security](https://help.sigmacomputing.com/docs/example-representation-data-model-with-column-level-security) — confirmed column hiding is a table-level `columnSecurities` array, not a per-column boolean
- [example: custom SQL element](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-custom-sql-element) — confirmed `source.kind: "sql"` as a fourth source kind alongside `warehouse-table`/`join`/`union`/`transpose`
- [example: list values control](https://help.sigmacomputing.com/docs/example-representation-data-model-with-a-list-values-control) — confirmed controls are page-level peer elements (`kind: "control"`) referencing a table's column by id, not part of a table's own composition; the example library has a dozen-plus near-duplicate control variants (text/number/date input, sliders, switches, etc.), none of which are modeled

`assert_sigma_spec` also covers correctness properties that aren't specific to any one Sigma example: `freeze_id` determinism across identical calls, table/column id stability across `database`/`schema`/`identifier` casing, that a shared `key` across two tables bound to different identifiers doesn't collide on `id`, and that leaving `columns` empty on `sigma_data_models.table()` auto-populates real passthrough columns from the live relation (only exercisable via `dbt run-operation`, since it requires `execute=True` - the demo model always passes explicit `columns` so `dbt parse` stays connection-free for the whole project).

A second set of macros (`assert_duplicate_column_rejected`, `assert_duplicate_metric_rejected`, `assert_duplicate_table_key_rejected`, `assert_unknown_relationship_from_rejected`, `assert_unknown_relationship_to_rejected`, `assert_unknown_relationship_column_rejected`, `assert_unknown_folder_column_rejected`, `assert_unknown_filter_column_rejected`, `assert_nonexistent_relation_rejected`) are each expected to raise a compiler error — the test script invokes them via `dbt run-operation` and fails if any of them *succeeds*, since that would mean the corresponding validation regressed.

## Switching Adapters

Two profile targets are defined in `profiles.yml`: `sigma_integration_tests_duckdb` (default, no credentials needed) and `sigma_integration_tests_snowflake` (dummy credentials — documents the adapter this package targets in production, since Sigma itself only connects to Snowflake). Pass `--profile` to pick one, or edit `profile:` in `dbt_project.yml` to change the default.
