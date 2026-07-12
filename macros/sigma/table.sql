{% macro table(key, identifier=none, database=none, schema=none, element_name=none, description=none, primary_key=none, columns=[], metrics=[]) %}
{% set database = database or target.database %}
{% set schema = schema or target.schema %}
{% set identifier = identifier or key %}
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
    {% do columns.append(column.name.lower()) %}
  {% endfor %}
{% endif %}
{% set frozen_columns = [] %}
{% for column in columns %}
  {% set column = sigma_data_models.column(column) if column is string else column %}
  {% set frozen_column = column.copy() %}
  {% do frozen_column.update({
    "element_id": sigma_data_models.freeze_id('column:' ~ key ~ '.' ~ column.name),
    "semantic": column.semantic or ('key' if column.name == primary_key else none),
  }) %}
  {% do frozen_columns.append(frozen_column) %}
{% endfor %}
{% set metrics_is_mapping = metrics is mapping %}
{% set frozen_metrics = [] %}
{% for metric in (metrics.items() if metrics_is_mapping else metrics) %}
  {% set metric = sigma_data_models.metric(metric[0], metric[1]) if metrics_is_mapping else metric %}
  {% set frozen_metric = metric.copy() %}
  {% do frozen_metric.update({"element_id": sigma_data_models.freeze_id('metric:' ~ key ~ '.' ~ metric.name)}) %}
  {% do frozen_metrics.append(frozen_metric) %}
{% endfor %}
{% do return({
  "key": key,
  "element_id": sigma_data_models.freeze_id('table:' ~ key),
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
