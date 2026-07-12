{# Normalizes a metric into an intent descriptor - `sigma_data_models.table()` resolves this
   into the real Sigma metric shape ({id, formula, name}), since the id needs table-level
   identifier_path context that isn't available here. #}
{% macro metric(name, formula, display_name=none) %}
{% do return({
  "name": name | lower,
  "formula": formula,
  "display_name": display_name,
}) %}
{% endmacro %}
