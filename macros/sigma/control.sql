{% macro control(name, type, targets=[], display_name=none, page=none, options={}) %}
{% do return({
  "name": name,
  "type": type,
  "targets": targets,
  "display_name": display_name,
  "_page": page,
  "options": options,
}) %}
{% endmacro %}
