{% macro column(name, display_name=none, semantic=none, hidden=false, group=none, description=none) %}
{% do return({
  "name": name,
  "display_name": display_name or sigma_data_models.titleize(name),
  "semantic": semantic,
  "hidden": hidden,
  "group": group,
  "description": description,
}) %}
{% endmacro %}
