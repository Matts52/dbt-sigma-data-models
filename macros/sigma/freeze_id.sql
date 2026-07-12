{# Same path in -> same id out, every compile, forever (until the path itself changes).
   Callers pass a path built from stable identifiers - a table's physical
   database.schema.identifier for table/column/metric ids, a relationship's key for
   relationship ids - never a value that can change across runs (timestamps, row counts,
   run_started_at) - otherwise this stops being deterministic and every recompile produces
   a new id. This only guarantees stability at compile time; Sigma may still assign its own
   id for tables/columns on the first live sync, independent of what's frozen here. #}
{% macro freeze_id(path) %}
{% do return(local_md5(path)) %}
{% endmacro %}
