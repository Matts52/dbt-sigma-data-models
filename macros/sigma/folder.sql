{# Normalizes a folder into an intent descriptor - `sigma_data_models.table()` resolves the
   member `columns` (by name) into the real Sigma folder shape ({id, name, items}), where
   `items` is a list of the member columns' ids. #}
{% macro folder(name, columns) %}
{% do return({
  "name": name,
  "columns": columns,
}) %}
{% endmacro %}
