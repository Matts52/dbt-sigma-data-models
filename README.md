# dbt-sigma-data-models

Compose [Sigma data models](https://help.sigmacomputing.com/docs/manage-data-models-as-code) from a handful of macros instead of hand-writing the full Sigma JSON/YAML spec. The compiled spec is attached to a dbt model's `meta` config, so it lands directly in `manifest.json` on `dbt parse` / `dbt compile`. Nothing about the underlying tables is ever touched; a warehouse connection is only needed if you lean on `sigma_data_models.table()`'s column auto-population (see below) — with explicit `columns`, `dbt parse` alone is enough.

## Usage

Define one dbt model per Sigma data model. The model's only job is to carry the compiled spec in its config; give it a trivial `select` body and a non-materializing config:

```sql
-- models/sigma_territory_carving.sql
{% set sigma_data_model = sigma_data_models.model(
    name='Territory Carving',
    tables=[
      sigma_data_models.table('accounts', 'stg_accounts', primary_key='account_guid',
        columns=['account_guid', 'account_name'],
        metrics={'count_accounts': 'CountDistinct([account_guid])'}),
      sigma_data_models.table('employees', 'stg_employees', primary_key='employee_guid',
        columns=['employee_guid', 'employee_name']),
    ],
    relationships=[
      ('accounts', 'account_owner_user_guid', 'employees', 'employee_guid'),
    ],
) %}

{{ sigma_data_models.materialize(sigma_data_model) }}

select 1
```

Run `dbt parse` (or `dbt compile`) and the fully composed Sigma JSON is available at `manifest.json -> nodes -> model.<project>.sigma_territory_carving -> config.meta.sigma_data_model`.

Pair it with an `exposures:` entry to get native dbt selection over everything the data model depends on:

```yaml
exposures:
  - name: territory_carving
    type: analysis
    depends_on:
      - ref('stg_accounts')
      - ref('stg_employees')
      - ref('sigma_territory_carving')
```

`dbt list -s +exposure:territory_carving` then resolves the full upstream lineage feeding the data model.

## Macros

| Macro | Purpose |
| --- | --- |
| `sigma_data_models.model(name, tables, relationships=[], page_name=none, connection_id=none, folder_id=none, data_model_id=none)` | Top-level data model. |
| `sigma_data_models.table(key, identifier=none, database=none, schema=none, element_name=none, description=none, primary_key=none, columns=[], metrics=[])` | A Sigma table. `identifier` is positional and defaults to `key`; `database`/`schema` default to the current target. |
| `sigma_data_models.column(name, display_name=none, semantic=none, hidden=false, group=none, description=none)` | A column on a table. Only needed for overrides — see below. |
| `sigma_data_models.metric(name, expression, display_name=none, description=none)` | A metric on a table. Only needed for overrides — see below. |
| `sigma_data_models.relationship(from, from_column, to, to_column, type='left', name=none)` | A join between two tables. Only needed for overrides — see below. |
| `sigma_data_models.materialize(spec, materialized='view')` | Wires a composed spec into the model's `config(meta=...)`. |

`display_name`/`element_name` default to a title-cased version of the key when omitted.

**`identifier`** is `sigma_data_models.table()`'s second positional arg, so `sigma_data_models.table('accounts', 'stg_accounts', ...)` works without spelling out `identifier=`. If the Sigma key and the dbt model name already match, skip it entirely — it defaults to `key`.

**Columns** can be bare strings — `columns=['account_guid', 'account_name']` — and `sigma_data_models.column(...)` is only needed when a column needs a non-default `display_name`/`semantic`/`hidden`/`group`/`description`. Whichever column's name matches the table's `primary_key` automatically gets `semantic='key'`, whether it's a bare string or an explicit `sigma_data_models.column(...)` call that doesn't already set `semantic` itself.

**Metrics** can be a plain `{name: expression}` dict — `metrics={'count_accounts': 'CountDistinct([account_guid])'}` — and `sigma_data_models.metric(...)` is only needed for a `display_name`/`description` override.

**Relationships** can be a bare `(from, from_column, to, to_column)` tuple — `sigma_data_models.relationship(...)` is only needed to set `type` or `name`.

Leaving `columns` off `sigma_data_models.table()` entirely (rather than passing bare strings) auto-populates every column from the live warehouse relation (`adapter.get_columns_in_relation`) instead. This requires a real connection, so it only works under `dbt run`/`dbt compile` (where `execute` is true) — under connection-free `dbt parse`, a table with no `columns` raises a clear compiler error rather than silently compiling to zero columns. Pass `columns` explicitly to keep a table `dbt parse`-able without a connection.

## Frozen element ids

`element_id` is never supplied by hand. Every table/column/metric/relationship's id comes from `sigma_data_models.freeze_id(path)`, which is `local_md5(path)` over a path built from stable authoring keys — `'table:' ~ key`, `'column:' ~ key ~ '.' ~ column.name`, `'metric:' ~ key ~ '.' ~ metric.name`, `'relationship:' ~ key`. Same path in, same id out, on every compile, forever — the id only changes if the underlying key/name itself is renamed. This is what "frozen" means here: renaming a `display_name`, `description`, or column order never reshuffles ids, so recompiling the same model doesn't produce a spurious diff.

`data_model_id` is the one exception — it's `none` unless explicitly passed. Unlike element ids, it has no deterministic fallback: it's assigned by Sigma the first time the data model is created, so there's nothing to freeze until that's happened. Once you know it (e.g. after a first successful push), pass it back in via `sigma_data_models.model(data_model_id=...)`.

What this does **not** guarantee: Sigma-side permanence. Per the `sigma-data-models` sync tooling's own docs, Sigma assigns its own opaque internal id to every table/column element on first sync, ignoring whatever id string was submitted — the only way to learn the real id is a POST-then-GET round trip against the live API, which is outside what a dbt macro can do at compile time. Relationship and metric ids are best-effort only; they aren't reliably preserved by the API even in Sigma's own production sync. So treat `freeze_id` as a guarantee of *compile-time* determinism (no diff noise across recompiles), not a promise that the id you see in `manifest.json` is the one Sigma ends up using — reconciling that lives in whatever tool actually pushes the compiled spec to Sigma's API.

`connection_id`/`folder_id` are Sigma workspace concepts with no dbt equivalent to derive them from. They default to the `sigma_connection_id`/`sigma_folder_id` project vars (set once for the org/workspace) and can be overridden per data model by passing them to `sigma_data_models.model()` directly:

```yaml
# dbt_project.yml
vars:
  sigma_connection_id: 17edf046-9636-4d9b-a13f-d034bec2d600
  sigma_folder_id: e7c79c61-94d4-458e-ab4c-f581a4c04a4c
```

## Why a model instead of a plain YAML block

dbt only exposes `var()`/`env_var()` (not `ref()` or custom macros) to the Jinja context used to render `exposures:`/`models:` YAML properties, so the spec can't be composed there. A `.sql` model file gets the full macro/`ref()` context, so that's where composition happens; the model's `select` body is intentionally inert.

## Integration tests

See `integration_tests/` for a runnable example (seeds + staging models + a `sigma_*` model + a companion exposure). From `integration_tests/`:

```bash
dbt deps
DBT_PROFILES_DIR=. dbt parse --no-partial-parse
```
