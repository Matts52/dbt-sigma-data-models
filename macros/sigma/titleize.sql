{% macro titleize(value) %}
{% do return(value.replace('_', ' ').replace('-', ' ').title()) %}
{% endmacro %}
