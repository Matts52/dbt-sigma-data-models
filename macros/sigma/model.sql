{% macro model(name, tables, relationships=[], page_name=none, connection_id=none, folder_id=none, data_model_id=none) %}
{% set table_keys = [] %}
{% for t in tables %}
  {% if t.key in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): duplicate table key '" ~ t.key ~ "' - table keys must be unique within a single model, since relationships resolve `from`/`to` against them.") %}
  {% endif %}
  {% do table_keys.append(t.key) %}
{% endfor %}
{% set normalized_relationships = [] %}
{% for rel in relationships %}
  {% set rel = sigma_data_models.relationship(*rel) if rel is sequence and rel is not mapping and rel is not string else rel %}
  {% if rel.from not in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship `from` references unknown table key '" ~ rel.from ~ "' - must be one of " ~ table_keys) %}
  {% endif %}
  {% if rel.to not in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship `to` references unknown table key '" ~ rel.to ~ "' - must be one of " ~ table_keys) %}
  {% endif %}
  {% do normalized_relationships.append(rel) %}
{% endfor %}
{% do return({
  "data_model_id": data_model_id,
  "name": name,
  "page_name": page_name or name,
  "connection_id": connection_id or var('sigma_connection_id', none),
  "folder_id": folder_id or var('sigma_folder_id', none),
  "tables": tables,
  "relationships": normalized_relationships,
}) %}
{% endmacro %}
