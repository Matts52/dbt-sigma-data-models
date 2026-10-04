{% macro materialize(spec, materialized='view') %}
{% set connection_tags = spec.get('_connection_tags', []) %}
{% set clean_spec = {} %}
{% for k, v in spec.items() %}
  {% if k != '_connection_tags' %}{% do clean_spec.update({k: v}) %}{% endif %}
{% endfor %}
{% set meta = {'sigma_data_model': clean_spec} %}
{% if connection_tags %}{% do meta.update({'sigma_data_model_connection_tags': connection_tags}) %}{% endif %}
{{ config(materialized=materialized, meta=meta) }}
{% endmacro %}
