{% macro _resolve_column_id(context, table_key, table, column_name) %}
{# Validates column_name exists on table and returns its frozen column id. context is
   included verbatim in the compiler error so callers can give precise error messages. #}
{% set column_name = column_name | lower %}
{% if column_name not in table._column_ids %}
  {% do exceptions.raise_compiler_error(context ~ " references unknown column '" ~ column_name ~ "' on table '" ~ table_key ~ "' - must be one of " ~ (table._column_ids.keys() | list)) %}
{% endif %}
{% do return(table._column_ids[column_name]) %}
{% endmacro %}
