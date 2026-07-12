# dbt-sigma-data-models

Compose [Sigma data models](https://help.sigmacomputing.com/docs/manage-data-models-as-code) from a handful of macros instead of hand-writing the full Sigma JSON spec. The compiled spec is attached to a dbt model's `meta` config, so it lands directly in `manifest.json` on `dbt parse` / `dbt compile`. Nothing about the underlying tables is ever touched; a warehouse connection is only needed if you lean on `sigma_data_models.table()`'s column auto-population (see below) — with explicit `columns`, `dbt parse` alone is enough.

The compiled shape follows Sigma's own documented [data model representation examples](https://help.sigmacomputing.com/docs/data-model-representation-example-library) as closely as this package's scope allows — see [Coverage](#coverage) for exactly what's modeled and what isn't, and `integration_tests/README.md` for which specific example each shape is checked against.

## Usage

Define one dbt model per Sigma data model. The model's only job is to carry the compiled spec in its config; give it a trivial `select` body and a non-materializing config:

```sql
-- models/sigma_territory_carving.sql
{% set sigma_data_model = sigma_data_models.model(
    name='Territory Carving',
    tables=[
      sigma_data_models.table('accounts', 'stg_accounts',
        columns=['account_guid', 'account_name', 'account_owner_user_guid'],
        metrics={'count_accounts': 'CountDistinct([Account Guid])'}),
      sigma_data_models.table('employees', 'stg_employees',
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
| `sigma_data_models.model(name, tables, relationships=[], page_name=none, folder_id=none, data_model_id=none)` | Top-level data model - one page, assembled from `tables`. |
| `sigma_data_models.table(key, identifier=none, database=none, schema=none, connection_id=none, columns=[], metrics=[], folders=[])` | A Sigma table element bound to a warehouse relation. `identifier` is positional and defaults to `key`; `database`/`schema` default to the current target. |
| `sigma_data_models.column(name, formula=none, display_name=none)` | A column. Only needed for a calculated column or a `display_name` override — see below. |
| `sigma_data_models.metric(name, formula, display_name=none)` | A metric on a table. Only needed for a `display_name` override — see below. |
| `sigma_data_models.relationship(from, from_column, to, to_column, name=none)` | A declared lineage link between two tables. Only needed for a `name` override — see below. |
| `sigma_data_models.folder(name, columns)` | Groups a named subset of a table's columns for display. |
| `sigma_data_models.filter(column, kind, options={})` | A filter on a table column. `kind`-specific fields go in `options`, verbatim. |
| `sigma_data_models.materialize(spec, materialized='view')` | Wires a composed spec into the model's `config(meta=...)`. |

**`identifier`** is `sigma_data_models.table()`'s second positional arg, so `sigma_data_models.table('accounts', 'stg_accounts', ...)` works without spelling out `identifier=`. If the Sigma key and the dbt model name already match, skip it entirely — it defaults to `key`.

**Columns** can be bare strings — `columns=['account_guid', 'account_name']` — which produce a *passthrough* column bound directly to the warehouse column: `{id, formula: '[stg_accounts/Account Guid]'}`, with no `name` field, matching an unmodified source column in Sigma's own representation. Passing an explicit `formula` via `sigma_data_models.column(name, formula=...)` instead produces a *calculated* column — `{id, formula, name}` — for anything Sigma itself couldn't derive from the source column alone. Column names are always lowercased and must be unique within a table; a duplicate raises a compiler error rather than silently colliding on `id`.

Leaving `columns` off `sigma_data_models.table()` entirely (rather than passing bare strings) auto-populates every column as a passthrough column from the live warehouse relation (`adapter.get_columns_in_relation`) instead. This requires a real connection, so it only works under `dbt run`/`dbt compile` (where `execute` is true) — under connection-free `dbt parse`, a table with no `columns` raises a clear compiler error rather than silently compiling to zero columns. Pass `columns` explicitly to keep a table `dbt parse`-able without a connection. If the relation can't be found (wrong `identifier`/`database`/`schema`, or it just hasn't been built yet), auto-population raises a compiler error too, rather than silently compiling a table with zero columns.

**Metrics** can be a plain `{name: formula}` dict — `metrics={'count_accounts': 'CountDistinct([Account Guid])'}` — and `sigma_data_models.metric(...)` is only needed for a `display_name` override. Metric names must be unique within a table; a duplicate raises a compiler error.

**Folders** group a table's own columns by name — `folders=[sigma_data_models.folder('Identifiers', columns=['account_guid'])]` — each `columns` entry must be an actual column on that table, or `sigma_data_models.table()` raises a compiler error. `metrics`/`folders`/`filters` are omitted entirely from the emitted table when empty, rather than emitted as an empty list, matching Sigma's own representations (which never show an empty `metrics`/`folders`/`filters` array on a table that doesn't have any).

**Filters** target a single column and pass their `kind`-specific fields straight through — `filters=[sigma_data_models.filter('account_industry', kind='list', options={'mode': 'include', 'values': ['Manufacturing']})]`. `options` uses Sigma's own field names directly (e.g. `min`/`max` for `kind='number-range'`, `mode`/`value`/`case` for `kind='text-match'`), so there's no per-`kind` macro surface to keep in sync with Sigma's filter types. `column` must be an actual column on that table, or `sigma_data_models.table()` raises a compiler error.

**Relationships** can be a bare `(from, from_column, to, to_column)` tuple — `sigma_data_models.relationship(...)` is only needed to set `name`. A relationship in Sigma is a declared lineage link (used for cross-table calculations), not a row-blending join — it has no join type. Sigma's actual join concept (`source.kind: "join"`, a distinct element that blends two tables' rows) isn't modeled by this package yet; see [Coverage](#coverage). `from`/`to` must reference a `key` present in the same `sigma_data_models.model()` call's `tables=[...]`, and `from_column`/`to_column` must be actual columns on those tables — any of these being wrong raises a compiler error rather than silently compiling a broken reference.

`sigma_data_models.model()` also requires `key` to be unique *within* one call's `tables=[...]` — unlike across separate models (see below), a duplicate here is genuinely ambiguous, since it's what `relationships=[...]` resolves `from`/`to` against, so it raises a compiler error.

## Frozen element ids

`id` is never supplied by hand. Every table/column/metric/folder/filter's id comes from `sigma_data_models.freeze_id(path)`, which is `local_md5(path)` over a path built from the table's physical `database.schema.identifier` — `'table:' ~ identifier_path`, `'column:' ~ identifier_path ~ '.' ~ column.name`, `'metric:' ~ identifier_path ~ '.' ~ metric.name`, `'folder:' ~ identifier_path ~ '.' ~ folder.name`, `'filter:' ~ identifier_path ~ '.' ~ column.name ~ '.' ~ kind`. Relationship ids use `'relationship:' ~ from ~ '_to_' ~ to ~ '_' ~ from_column ~ '_' ~ to_column` instead, since relationships only need to be unique within the single `sigma_data_models.model()` call that wires them — `to_column` is included so two relationships between the same table pair on the same `from_column` (e.g. a polymorphic join) don't collide.

Same path in, same id out, on every compile, forever — the id only changes if the identifier binding itself is renamed. This is what "frozen" means here: reordering columns, adding a metric, or renaming a calculated column's `display_name` never reshuffles other elements' ids, so recompiling the same model doesn't produce a spurious diff. It also means `key` is purely a local label for wiring `tables=[...]`/`relationships=[...]`/`folders=[...]` within one `sigma_data_models.model()` call — the same `key` (e.g. `'accounts'`) can be reused across unrelated data models without any id collision, since ids are frozen off the identifier binding, not the key.

The identifier path is lowercased before hashing, so the same physical table freezes to the same id regardless of the casing it's bound with — e.g. Snowflake uppercases unquoted identifiers, so a `database`/`schema` typed differently across two callers (or two environments) would otherwise silently produce two different ids for what's really one table.

`dataModelId` is the one exception — it's `none` unless explicitly passed via `sigma_data_models.model(data_model_id=...)`, since it's assigned by Sigma the first time a data model is created (there's nothing to freeze before that). Pass it back in once known to target an update instead of a create. `pages[0].id` also has no frozen value — it's always left `''`, since [creating a data model from a code representation](https://help.sigmacomputing.com/docs/create-a-data-model-from-a-code-representation) documents that Sigma assigns it and expects it blank.

What this does **not** guarantee for the ids this package *does* freeze (table/column/metric/folder/filter/relationship): Sigma-side permanence. Per Sigma's own docs, on the first live sync Sigma may assign its own internal id to an element, independent of what's frozen here — the only way to learn the real id is a round trip against the live API, which is outside what a dbt macro can do at compile time. So treat `freeze_id` as a guarantee of *compile-time* determinism (no diff noise across recompiles), not a promise that the id you see in `manifest.json` is the one Sigma ends up using.

`connection_id`/`folder_id` default to the `sigma_connection_id`/`sigma_folder_id` project vars (set once for the org/workspace), and can be overridden per table (`connection_id`) or per model (`folder_id`):

```yaml
# dbt_project.yml
vars:
  sigma_connection_id: 17edf046-9636-4d9b-a13f-d034bec2d600
  sigma_folder_id: e7c79c61-94d4-458e-ab4c-f581a4c04a4c
```

## Coverage

Modeled, matching Sigma's own [example representations](https://help.sigmacomputing.com/docs/data-model-representation-example-library):

- Warehouse-bound tables (`source.kind: "warehouse-table"`)
- Passthrough and calculated columns
- Metrics
- Relationships (declared lineage links, nested under their source table)
- Folders (named column groupings)
- Filters (`kind`-specific fields passed through verbatim)

Not modeled - unsupported inputs are simply not exposed by these macros, so there's nothing to accidentally get wrong:

- **Joins** (`source.kind: "join"`) - a distinct element that blends two tables' rows, different from a relationship (see above)
- **Unions** (`source.kind: "union"`) - a distinct element combining multiple sources by matched columns
- **Transposed tables** (`source.kind: "transpose"`) - a distinct element pivoting a source table's columns to rows
- Custom SQL sources (`source.kind: "sql"`)
- Groupings (statistical `groupBy`, distinct from folders)
- Column-level security (`columnSecurities`)
- Column/metric `format` (number/datetime display formatting)
- Multi-page data models (`sigma_data_models.model()` always produces exactly one page)
- Input controls (list values, text/number/date input, sliders, etc.) - these are page-level peer elements (`kind: "control"`), not part of a table's own composition

## Why a model instead of a plain YAML block

dbt only exposes `var()`/`env_var()` (not `ref()` or custom macros) to the Jinja context used to render `exposures:`/`models:` YAML properties, so the spec can't be composed there. A `.sql` model file gets the full macro/`ref()` context, so that's where composition happens; the model's `select` body is intentionally inert.

## Integration tests

See `integration_tests/` for a runnable example (seeds + staging models + a `sigma_*` model exercising every supported shape + a companion exposure), and `integration_tests/README.md` for which Sigma example each shape is checked against. From `integration_tests/`:

```bash
dbt deps
DBT_PROFILES_DIR=. dbt parse --no-partial-parse
```
