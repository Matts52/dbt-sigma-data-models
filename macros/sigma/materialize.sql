{% macro materialize(spec, materialized='view') %}
{{ config(materialized=materialized, meta={'sigma_data_model': spec}) }}
{% endmacro %}
