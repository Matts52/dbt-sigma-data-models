{% macro materialize(spec, materialized='view') %}
{% set tags = spec.get('_tags', []) %}
{% set clean_spec = {} %}
{% for k, v in spec.items() %}
  {% if k != '_tags' %}{% do clean_spec.update({k: v}) %}{% endif %}
{% endfor %}
{% set meta = {'sigma_data_model': clean_spec} %}
{% if tags %}{% do meta.update({'sigma_data_model_tags': tags}) %}{% endif %}
{{ config(materialized=materialized, meta=meta) }}
{% endmacro %}
