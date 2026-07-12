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

`sigma_data_models.materialize()` sets `meta` via `config(meta=...)`, which replaces `meta` wholesale rather than merging it — if the model (or a `+meta:` in `dbt_project.yml`) sets other `meta` keys elsewhere, calling `materialize()` will drop them. Keep these models single-purpose, as shown above, and set any other `meta` you need on a different model.

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
| `sigma_data_models.column(name, display_name=none, semantic=none, hidden=false, group=none, description=none, type=none)` | A column on a table. Only needed for overrides — see below. |
| `sigma_data_models.metric(name, expression, display_name=none, description=none)` | A metric on a table. Only needed for overrides — see below. |
| `sigma_data_models.relationship(from, from_column, to, to_column, join_type='left', name=none)` | A join between two tables. Only needed for overrides — see below. |
| `sigma_data_models.materialize(spec, materialized='view')` | Wires a composed spec into the model's `config(meta=...)`. |

`display_name`/`element_name` default to a title-cased version of the key when omitted.

**`identifier`** is `sigma_data_models.table()`'s second positional arg, so `sigma_data_models.table('accounts', 'stg_accounts', ...)` works without spelling out `identifier=`. If the Sigma key and the dbt model name already match, skip it entirely — it defaults to `key`.

**Columns** can be bare strings — `columns=['account_guid', 'account_name']` — and `sigma_data_models.column(...)` is only needed when a column needs a non-default `display_name`/`semantic`/`hidden`/`group`/`description`/`type`. Whichever column's name matches the table's `primary_key` automatically gets `semantic='key'`, whether it's a bare string or an explicit `sigma_data_models.column(...)` call that doesn't already set `semantic` itself. Column names are always lowercased (and `primary_key` is matched case-insensitively), so mixed-case source columns still resolve correctly.

Explicitly-passed columns don't get a `type` unless you set one yourself — only auto-populated columns (see below) get one derived automatically, since that's the only path with real type information available. `map_type` buckets the adapter's raw SQL type into one of `text`/`number`/`boolean`/`date`/`datetime`/`variant`; pass `type=` explicitly to override it.

**Metrics** can be a plain `{name: expression}` dict — `metrics={'count_accounts': 'CountDistinct([account_guid])'}` — and `sigma_data_models.metric(...)` is only needed for a `display_name`/`description` override. Column and metric names must each be unique within a table — a duplicate raises a compiler error rather than silently colliding on `element_id`.

**Relationships** can be a bare `(from, from_column, to, to_column)` tuple — `sigma_data_models.relationship(...)` is only needed to set `join_type` (default `'left'`; note this is a distinct parameter from `sigma_data_models.column()`'s `type`, which is a data type, not a join type) or `name`. `from`/`to` must reference a `key` present in the same `sigma_data_models.model()` call's `tables=[...]` — an unrecognized key raises a compiler error rather than silently compiling a broken reference.

`sigma_data_models.model()` also requires `key` to be unique *within* one call's `tables=[...]` — unlike across separate models (see below), a duplicate here is genuinely ambiguous, since it's what `relationships=[...]` resolves `from`/`to` against, so it raises a compiler error. Likewise, `primary_key` must match one of the table's actual column names, or `sigma_data_models.table()` raises rather than silently omitting the key column.

Leaving `columns` off `sigma_data_models.table()` entirely (rather than passing bare strings) auto-populates every column from the live warehouse relation (`adapter.get_columns_in_relation`) instead, with `type` set from the adapter's reported SQL type via `sigma_data_models.map_type()`. This requires a real connection, so it only works under `dbt run`/`dbt compile` (where `execute` is true) — under connection-free `dbt parse`, a table with no `columns` raises a clear compiler error rather than silently compiling to zero columns. Pass `columns` explicitly to keep a table `dbt parse`-able without a connection.

## Frozen element ids

`element_id` is never supplied by hand. Every table/column/metric's id comes from `sigma_data_models.freeze_id(path)`, which is `local_md5(path)` over a path built from the table's physical `database.schema.identifier` — `'table:' ~ identifier_path`, `'column:' ~ identifier_path ~ '.' ~ column.name`, `'metric:' ~ identifier_path ~ '.' ~ metric.name`. Relationship ids use `'relationship:' ~ from ~ '_to_' ~ to ~ '_' ~ from_column ~ '_' ~ to_column` instead, since relationships only need to be unique within the single `sigma_data_models.model()` call that wires them — `to_column` is included so two relationships between the same table pair on the same `from_column` (e.g. a polymorphic join) don't collide.

Same path in, same id out, on every compile, forever — the id only changes if the identifier binding itself is renamed. This is what "frozen" means here: renaming a `display_name`, `description`, or column order never reshuffles ids, so recompiling the same model doesn't produce a spurious diff. It also means `key` is purely a local label for wiring `tables=[...]`/`relationships=[...]` within one `sigma_data_models.model()` call — the same `key` (e.g. `'accounts'`) can be reused across unrelated data models without any id collision, since ids are frozen off the identifier binding, not the key.

The identifier path is lowercased before hashing, so the same physical table freezes to the same id regardless of the casing it's bound with — e.g. Snowflake uppercases unquoted identifiers, so a `database`/`schema` typed differently across two callers (or two environments) would otherwise silently produce two different ids for what's really one table.

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
