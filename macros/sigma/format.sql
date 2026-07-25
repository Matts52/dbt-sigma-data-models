{# Constructs a Sigma format object for a column or metric element, controlling number/datetime
   display formatting - see https://help.sigmacomputing.com/docs/format-columns-and-metrics-in-the-code-representation-of-a-data-model.
   Pass the result as `format=` to sigma_data_models.column() or sigma_data_models.metric().

   Supported kinds and their allowed option keys:
     number:   formatString, decimalSymbol, digitGroupingSymbol, digitGroupingSize, currencySymbol
     datetime: formatString #}
{% macro format(kind, options={}) %}
{% if kind not in ['number', 'datetime'] %}
  {% do exceptions.raise_compiler_error(
    "sigma_data_models.format(): kind must be 'number' or 'datetime', got '" ~ kind ~ "'."
  ) %}
{% endif %}
{% set _allowed = {
  'number':   ['formatString', 'decimalSymbol', 'digitGroupingSymbol', 'digitGroupingSize', 'currencySymbol'],
  'datetime': ['formatString'],
} %}
{% for key in options %}
  {% if key not in _allowed[kind] %}
    {% do exceptions.raise_compiler_error(
      "sigma_data_models.format(): '" ~ key ~ "' is not a supported option for kind='" ~ kind ~ "'. "
      ~ "Allowed: " ~ (_allowed[kind] | join(', ')) ~ "."
    ) %}
  {% endif %}
{% endfor %}
{% set result = {"kind": kind} %}
{% do result.update(options) %}
{% do return(result) %}
{% endmacro %}
