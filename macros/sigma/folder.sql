{# Normalizes a folder into an intent descriptor - `sigma_data_models.table()` resolves the
   member `columns`/`metrics` (by name) into the real Sigma folder shape ({id, name, items}),
   where `items` is a list of the member columns'/metrics' ids (columns first, then metrics, in
   each list's declared order). #}
{% macro folder(name, columns=[], metrics=[]) %}
{% do return({
  "name": name,
  "columns": columns,
  "metrics": metrics,
}) %}
{% endmacro %}
