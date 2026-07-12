{% macro relationship(from, from_column, to, to_column, join_type='left', name=none) %}
{% set key = from ~ '_to_' ~ to ~ '_' ~ from_column ~ '_' ~ to_column %}
{% do return({
  "key": key,
  "element_id": sigma_data_models.freeze_id('relationship:' ~ key),
  "from": from,
  "from_column": from_column,
  "to": to,
  "to_column": to_column,
  "type": join_type,
  "name": name,
}) %}
{% endmacro %}
