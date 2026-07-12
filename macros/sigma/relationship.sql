{# Normalizes a relationship into an intent descriptor - `sigma_data_models.model()` resolves
   this into the real Sigma relationship shape ({id, targetElementId, keys, name}), since that
   requires looking up both tables' element/column ids, which only exists once every table in
   the model has been composed.

   Note there is no join type here: a Sigma "relationship" is a declared lineage link (used for
   cross-table calculations), not a row-blending join - Sigma's join concept is a distinct
   element kind (source.kind = "join") this package does not yet support. #}
{% macro relationship(from, from_column, to, to_column, name=none) %}
{% do return({
  "from": from,
  "from_column": from_column | lower,
  "to": to,
  "to_column": to_column | lower,
  "name": name,
}) %}
{% endmacro %}
