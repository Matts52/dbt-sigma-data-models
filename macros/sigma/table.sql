{% macro table(key, identifier=none, database=none, schema=none, element_name=none, description=none, primary_key=none, columns=[], metrics=[]) %}
{% set database = database or target.database %}
{% set schema = schema or target.schema %}
{% set identifier = identifier or key %}
{% set primary_key = primary_key | lower if primary_key else none %}
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
  {% for column in adapter.get_columns_in_relation(relation) %}
    {% do columns.append(sigma_data_models.column(column.name, type=sigma_data_models.map_type(column.data_type))) %}
  {% endfor %}
{% endif %}
{% set frozen_columns = [] %}
{% set column_names = [] %}
{% for column in columns %}
  {% set column = sigma_data_models.column(column) if column is string else column %}
  {% if column.name in column_names %}
    {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): duplicate column name '" ~ column.name ~ "' - column names must be unique within a table.") %}
  {% endif %}
  {% do column_names.append(column.name) %}
  {% set frozen_column = column.copy() %}
  {% do frozen_column.update({
    "element_id": sigma_data_models.freeze_id('column:' ~ identifier_path ~ '.' ~ column.name),
    "semantic": column.semantic or ('key' if column.name == primary_key else none),
  }) %}
  {% do frozen_columns.append(frozen_column) %}
{% endfor %}
{% if primary_key and primary_key not in column_names %}
  {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): primary_key '" ~ primary_key ~ "' does not match any column name - must be one of " ~ column_names) %}
{% endif %}
{% set metrics_is_mapping = metrics is mapping %}
{% set frozen_metrics = [] %}
{% set metric_names = [] %}
{% for metric in (metrics.items() if metrics_is_mapping else metrics) %}
  {% set metric = sigma_data_models.metric(metric[0], metric[1]) if metrics_is_mapping else metric %}
  {% if metric.name in metric_names %}
    {% do exceptions.raise_compiler_error("sigma_data_models.table('" ~ key ~ "'): duplicate metric name '" ~ metric.name ~ "' - metric names must be unique within a table.") %}
  {% endif %}
  {% do metric_names.append(metric.name) %}
  {% set frozen_metric = metric.copy() %}
  {% do frozen_metric.update({"element_id": sigma_data_models.freeze_id('metric:' ~ identifier_path ~ '.' ~ metric.name)}) %}
  {% do frozen_metrics.append(frozen_metric) %}
{% endfor %}
{% do return({
  "key": key,
  "element_id": sigma_data_models.freeze_id('table:' ~ identifier_path),
  "db": database,
  "schema": schema,
  "table": identifier,
  "element_name": element_name or sigma_data_models.titleize(key),
  "description": description,
  "primary_key": primary_key,
  "columns": frozen_columns,
  "metrics": frozen_metrics,
}) %}
{% endmacro %}
