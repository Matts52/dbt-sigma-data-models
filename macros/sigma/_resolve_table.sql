{% macro _resolve_table(context, table_key, table_by_key) %}
{# Validates table_key exists in table_by_key and returns the table dict. context is
   included verbatim in the compiler error so callers can give precise error messages. #}
{% if table_key not in table_by_key %}
  {% do exceptions.raise_compiler_error(context ~ " references unknown table key '" ~ table_key ~ "' - must be one of " ~ (table_by_key.keys() | list)) %}
{% endif %}
{% do return(table_by_key[table_key]) %}
{% endmacro %}
