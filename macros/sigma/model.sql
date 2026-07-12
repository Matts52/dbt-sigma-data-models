{% macro model(name, tables, relationships=[], page_name=none, folder_id=none, data_model_id=none) %}
{% set table_keys = [] %}
{% set table_by_key = {} %}
{% for t in tables %}
  {% if t.key in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): duplicate table key '" ~ t.key ~ "' - table keys must be unique within a single model, since relationships resolve `from`/`to` against them.") %}
  {% endif %}
  {% do table_keys.append(t.key) %}
  {% do table_by_key.update({t.key: t}) %}
{% endfor %}

{# Relationships nest inside their source table's element in Sigma's schema (not at the
   model level), and reference the target table by its real element id - both of which are
   only knowable once every table in this call has been composed, so resolution happens here
   rather than in sigma_data_models.relationship() itself. #}
{% for rel in relationships %}
  {% set rel = sigma_data_models.relationship(*rel) if rel is sequence and rel is not mapping and rel is not string else rel %}
  {% if rel.from not in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship `from` references unknown table key '" ~ rel.from ~ "' - must be one of " ~ table_keys) %}
  {% endif %}
  {% if rel.to not in table_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship `to` references unknown table key '" ~ rel.to ~ "' - must be one of " ~ table_keys) %}
  {% endif %}
  {% set source_table = table_by_key[rel.from] %}
  {% set target_table = table_by_key[rel.to] %}
  {% if rel.from_column not in source_table._column_ids %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship references unknown column '" ~ rel.from_column ~ "' on table '" ~ rel.from ~ "' - must be one of " ~ (source_table._column_ids.keys() | list)) %}
  {% endif %}
  {% if rel.to_column not in target_table._column_ids %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): relationship references unknown column '" ~ rel.to_column ~ "' on table '" ~ rel.to ~ "' - must be one of " ~ (target_table._column_ids.keys() | list)) %}
  {% endif %}
  {% set relationship_key = rel.from ~ '_to_' ~ rel.to ~ '_' ~ rel.from_column ~ '_' ~ rel.to_column %}
  {% set relationship_entry = {
    "id": sigma_data_models.freeze_id('relationship:' ~ relationship_key),
    "targetElementId": target_table.id,
    "keys": [{
      "sourceColumnId": source_table._column_ids[rel.from_column],
      "targetColumnId": target_table._column_ids[rel.to_column],
    }],
    "name": rel.name,
  } %}
  {% if 'relationships' not in source_table %}
    {% do source_table.update({"relationships": []}) %}
  {% endif %}
  {% do source_table.relationships.append(relationship_entry) %}
{% endfor %}

{# Strip internal-only fields (`key`, `_column_ids`) before emitting - neither is a real
   field in Sigma's schema, they only exist to resolve relationships/folders above. #}
{% set elements = [] %}
{% for t in tables %}
  {% set clean_element = {} %}
  {% for field_name, field_value in t.items() %}
    {% if not field_name.startswith('_') and field_name != 'key' %}
      {% do clean_element.update({field_name: field_value}) %}
    {% endif %}
  {% endfor %}
  {% do elements.append(clean_element) %}
{% endfor %}

{% do return({
  "dataModelId": data_model_id,
  "name": name,
  "folderId": folder_id or var('sigma_folder_id', none),
  "schemaVersion": 1,
  "pages": [
    {
      "id": "",
      "name": page_name or name,
      "elements": elements,
    }
  ],
}) %}
{% endmacro %}
