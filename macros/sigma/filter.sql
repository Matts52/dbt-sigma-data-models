{# Normalizes a filter into an intent descriptor - `sigma_data_models.table()` resolves the
   `column` (by name) into the real Sigma filter shape (`{id, columnId, kind, ...}`), where
   `...` is whatever kind-specific fields `options` passes through verbatim (e.g. `min`/`max`
   for `kind='number-range'`, `mode`/`values` for `kind='list'`, `mode`/`value`/`case` for
   `kind='text-match'`) - see
   https://help.sigmacomputing.com/docs/example-representation-data-model-with-filters.
   `options` uses Sigma's own field names directly (including `includeNulls`), so no
   kind-specific macro surface is needed here. #}
{% macro filter(column, kind, options={}) %}
{% do return({
  "column": column | lower,
  "kind": kind,
  "options": options,
}) %}
{% endmacro %}
