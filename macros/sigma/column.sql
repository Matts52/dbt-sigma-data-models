{# Normalizes a column into an intent descriptor - `sigma_data_models.table()` resolves this
   into the real Sigma column shape ({id, formula} for a passthrough column bound to the
   warehouse, {id, formula, name} for a calculated one), since that requires table-level
   context (identifier_path for the id, the table's identifier for the default formula) that
   isn't available here. #}
{% macro column(name, formula=none, display_name=none) %}
{% do return({
  "name": name | lower,
  "formula": formula,
  "display_name": display_name,
}) %}
{% endmacro %}
