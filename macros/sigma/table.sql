{% macro table(key, identifier=none, database=none, schema=none, connection_id=none, columns=[], metrics=[], folders=[], filters=[]) %}
{% set database = database or target.database %}
{% set schema = schema or target.schema %}
{% set identifier = identifier or key %}
{% set connection_id = connection_id or var('sigma_connection_id', none) %}
{# Element ids are frozen off the physical db.schema.identifier a table is bound to, not
   `key` - `key` is only a local label used to wire relationships within one sigma.model()
   call, so the same `key` can be reused across separate models without id collisions.
   Lowercased because unquoted identifiers get uppercased by some adapters (e.g. Snowflake) -
   without this, the same physical table could freeze to different ids depending on which
   casing a caller (or environment) happens to pass in. #}
{% set identifier_path = (database ~ '.' ~ schema ~ '.' ~ identifier) | lower %}

{% if not columns %}
  {% if not execute %}
    {% do exceptions.raise_compiler_error(
      "sigma_data_models.table('" ~ key ~ "'): columns were left empty, which auto-populates them from " ~
      database ~ "." ~ schema ~ "." ~ identifier ~ " - that requires a live connection, so it " ~
      "only works under `dbt run`/`dbt compile`, not `dbt parse`. Pass `columns` explicitly to " ~
      "compile without a connection."
    ) %}
  {% endif %}
  {% set relation = api.Relation.create(database=database, schema=schema, identifier=identifier) %}
  {% set columns = [] %}
  {% for relation_column in adapter.get_columns_in_relation(relation) %}
    {% do columns.append(relation_column.name) %}
  {% endfor %}
{% endif %}

{% set frozen_columns = [] %}
{% set column_ids = {} %}
{% for column in columns %}
  {% set column = sigma_data_models.column(column) if column is string else column %}
  {% if column.name in column_ids %}
    {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): duplicate column name '" ~ column.name ~ "' - column names must be unique within a table.") %}
  {% endif %}
  {% set column_id = sigma_data_models.freeze_id('column:' ~ identifier_path ~ '.' ~ column.name) %}
  {% do column_ids.update({column.name: column_id}) %}
  {# A passthrough column (no explicit `formula`) is bound directly to the warehouse column via
     a `[TableIdentifier/Column Display Name]` formula reference, and carries no `name` field -
     matching Sigma's own representation of an unmodified source column. Passing `formula`
     explicitly makes it a calculated column instead, which does carry a `name`. #}
  {% set entry = {
    "id": column_id,
    "formula": column.formula or ('[' ~ identifier ~ '/' ~ sigma_data_models.titleize(column.name) ~ ']'),
  } %}
  {% if column.formula %}
    {% do entry.update({"name": column.display_name or sigma_data_models.titleize(column.name)}) %}
  {% endif %}
  {% do frozen_columns.append(entry) %}
{% endfor %}

{% set frozen_metrics = [] %}
{% set metrics_is_mapping = metrics is mapping %}
{% set metric_names = [] %}
{% for metric in (metrics.items() if metrics_is_mapping else metrics) %}
  {% set metric = sigma_data_models.metric(metric[0], metric[1]) if metrics_is_mapping else metric %}
  {% if metric.name in metric_names %}
    {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): duplicate metric name '" ~ metric.name ~ "' - metric names must be unique within a table.") %}
  {% endif %}
  {% do metric_names.append(metric.name) %}
  {% do frozen_metrics.append({
    "id": sigma_data_models.freeze_id('metric:' ~ identifier_path ~ '.' ~ metric.name),
    "formula": metric.formula,
    "name": metric.display_name or sigma_data_models.titleize(metric.name),
  }) %}
{% endfor %}

{% set frozen_folders = [] %}
{% for folder in folders %}
  {% set items = [] %}
  {% for column_name in folder.columns %}
    {% set column_name = column_name | lower %}
    {% if column_name not in column_ids %}
      {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): folder '" ~ folder.name ~ "' references unknown column '" ~ column_name ~ "' - must be one of " ~ (column_ids.keys() | list)) %}
    {% endif %}
    {% do items.append(column_ids[column_name]) %}
  {% endfor %}
  {% do frozen_folders.append({
    "id": sigma_data_models.freeze_id('folder:' ~ identifier_path ~ '.' ~ folder.name),
    "name": folder.name,
    "items": items,
  }) %}
{% endfor %}

{% set frozen_filters = [] %}
{% for filter in filters %}
  {% if filter.column not in column_ids %}
    {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): filter references unknown column '" ~ filter.column ~ "' - must be one of " ~ (column_ids.keys() | list)) %}
  {% endif %}
  {% set frozen_filter = {
    "id": sigma_data_models.freeze_id('filter:' ~ identifier_path ~ '.' ~ filter.column ~ '.' ~ filter.kind),
    "columnId": column_ids[filter.column],
    "kind": filter.kind,
  } %}
  {% do frozen_filter.update(filter.options) %}
  {% do frozen_filters.append(frozen_filter) %}
{% endfor %}

{% set order = [] %}
{% for column in frozen_columns %}
  {% do order.append(column.id) %}
{% endfor %}

{# `key` and `_column_ids` are internal-only - sigma_data_models.model() reads `_column_ids` to
   resolve relationship/folder column references, then strips both before emitting the final
   Sigma element, since neither is a real field in Sigma's schema. #}
{% set element = {
  "key": key,
  "_column_ids": column_ids,
  "id": sigma_data_models.freeze_id('table:' ~ identifier_path),
  "kind": "table",
  "source": {
    "connectionId": connection_id,
    "kind": "warehouse-table",
    "path": [database, schema, identifier],
  },
  "columns": frozen_columns,
  "order": order,
} %}
{% if frozen_metrics %}
  {% do element.update({"metrics": frozen_metrics}) %}
{% endif %}
{% if frozen_folders %}
  {% do element.update({"folders": frozen_folders}) %}
{% endif %}
{% if frozen_filters %}
  {% do element.update({"filters": frozen_filters}) %}
{% endif %}
{% do return(element) %}
{% endmacro %}
