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
   rather than in sigma_data_models.relationship() itself. Relationships resolve against all
   tables globally regardless of which page each table is assigned to, so cross-page
   relationships work transparently. #}
{% set relationship_keys = [] %}
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
  {% if relationship_key in relationship_keys %}
    {% do exceptions.raise_compiler_error("sigma_data_models.model('" ~ name ~ "'): duplicate relationship '" ~ relationship_key ~ "' - the same from/from_column/to/to_column combination was passed more than once.") %}
  {% endif %}
  {% do relationship_keys.append(relationship_key) %}
  {% set relationship_entry = {
    "id": sigma_data_models.freeze_id('relationship:' ~ relationship_key),
    "targetElementId": target_table.id,
    "keys": [{
      "sourceColumnId": source_table._column_ids[rel.from_column],
      "targetColumnId": target_table._column_ids[rel.to_column],
    }],
    "name": rel.name or (sigma_data_models.titleize(rel.from) ~ ' → ' ~ sigma_data_models.titleize(rel.to)),
  } %}
  {% if 'relationships' not in source_table %}
    {% do source_table.update({"relationships": []}) %}
  {% endif %}
  {% do source_table.relationships.append(relationship_entry) %}
{% endfor %}

{# Group tables into pages by their _page field, in first-appearance order. Tables with no
   _page set land on the default page, named by page_name (falling back to name). When all
   tables omit _page the output is a single page, identical to the previous single-page
   behaviour. #}
{% set default_page_name = page_name or name %}
{% set page_order = [] %}
{% set tables_by_page = {} %}
{% for t in tables %}
  {% set pname = t._page or default_page_name %}
  {% if pname not in page_order %}
    {% do page_order.append(pname) %}
    {% do tables_by_page.update({pname: []}) %}
  {% endif %}
  {% do tables_by_page[pname].append(t) %}
{% endfor %}

{# Strip internal-only fields (`key`, `_column_ids`, `_page`) before emitting - none are real
   fields in Sigma's schema, they only exist to resolve relationships/folders/page grouping. #}
{% set output_pages = [] %}
{% for pname in page_order %}
  {% set elements = [] %}
  {% for t in tables_by_page[pname] %}
    {% set clean_element = {} %}
    {% for field_name, field_value in t.items() %}
      {% if not field_name.startswith('_') and field_name != 'key' %}
        {% do clean_element.update({field_name: field_value}) %}
      {% endif %}
    {% endfor %}
    {% do elements.append(clean_element) %}
  {% endfor %}
  {% do output_pages.append({
    "id": "",
    "name": pname,
    "elements": elements,
  }) %}
{% endfor %}

{% do return({
  "dataModelId": data_model_id,
  "name": name,
  "folderId": folder_id or var('sigma_folder_id', none),
  "schemaVersion": 1,
  "pages": output_pages,
}) %}
{% endmacro %}
