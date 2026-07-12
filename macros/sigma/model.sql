{% macro model(name, tables, relationships=[], page_name=none, connection_id=none, folder_id=none, data_model_id=none) %}
{% set normalized_relationships = [] %}
{% for rel in relationships %}
  {% do normalized_relationships.append(sigma_data_models.relationship(*rel) if rel is sequence and rel is not mapping and rel is not string else rel) %}
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
