{# Best-effort bucketing of an adapter's raw SQL type string (e.g. Snowflake's
   "NUMBER(38,0)", DuckDB's "BIGINT") into a normalized Sigma-ish type. Callers
   that need an exact match can always override via sigma_data_models.column(type=...). #}
{% macro map_type(data_type) %}
{% set dtype = (data_type or '') | lower | trim %}
{# Numeric types are matched against the leading token, not a raw substring - 'int' as a
   substring would otherwise misfire on unrelated types like INTERVAL. #}
{% set leading_token = dtype.split('(')[0].split(' ')[0] %}
{% set number_tokens = ['int', 'integer', 'bigint', 'smallint', 'tinyint', 'mediumint', 'hugeint', 'numeric', 'number', 'decimal', 'float', 'float4', 'float8', 'double', 'real'] %}
{% if 'bool' in dtype %}
  {% do return('boolean') %}
{% elif 'timestamp' in dtype or 'datetime' in dtype %}
  {% do return('datetime') %}
{% elif leading_token == 'date' %}
  {% do return('date') %}
{% elif leading_token in number_tokens %}
  {% do return('number') %}
{% elif 'variant' in dtype or 'object' in dtype or 'json' in dtype or 'struct' in dtype or 'array' in dtype or 'map' in dtype %}
  {% do return('variant') %}
{% else %}
  {% do return('text') %}
{% endif %}
{% endmacro %}
