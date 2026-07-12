{% macro metric(name, expression, display_name=none, description=none) %}
{% do return({
  "name": name,
  "display_name": display_name or sigma_data_models.titleize(name),
  "expression": expression,
  "description": description,
}) %}
{% endmacro %}
