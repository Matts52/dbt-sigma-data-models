{# Asserts on the *shape* of composed specs, not just that compilation doesn't error. #}
{% macro assert_sigma_spec() %}

{# Duplicate `key`s across different sigma.table() calls must not collide on element_id -
   `key` is a local wiring label, ids are frozen off the physical identifier instead. #}
{% set table_a = sigma_data_models.table('shared_key', identifier='accounts', primary_key='ACCOUNT_GUID', columns=['account_guid']) %}
{% set table_b = sigma_data_models.table('shared_key', identifier='employees', primary_key='employee_guid', columns=['employee_guid']) %}
{% if table_a.element_id == table_b.element_id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: tables sharing a key but bound to different identifiers must not collide on element_id') %}
{% endif %}

{# freeze_id determinism: identical inputs must yield identical ids across independent calls. #}
{% set table_a_again = sigma_data_models.table('shared_key', identifier='accounts', primary_key='ACCOUNT_GUID', columns=['account_guid']) %}
{% if table_a.element_id != table_a_again.element_id or table_a.columns[0].element_id != table_a_again.columns[0].element_id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: freeze_id is not deterministic across identical calls') %}
{% endif %}

{# column names are lowercased regardless of source casing, and `primary_key` matching is case-insensitive. #}
{% if table_a.columns[0].name != 'account_guid' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: column names must be lowercased, got ' ~ table_a.columns[0].name) %}
{% endif %}
{% if table_a.columns[0].semantic != 'key' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: an uppercase primary_key must still match the lowercased column name') %}
{% endif %}

{# auto-populated columns must carry a mapped `type`. #}
{% set auto_table = sigma_data_models.table('auto_columns_check', identifier='accounts', primary_key='account_guid') %}
{% for column in auto_table.columns %}
  {% if not column.type %}
    {% do exceptions.raise_compiler_error('assert_sigma_spec: auto-populated column ' ~ column.name ~ ' is missing a mapped type') %}
  {% endif %}
{% endfor %}

{# relationships sharing from/to/from_column but differing only in to_column (a polymorphic-join
   shape) must not collide on element_id. #}
{% set rel_a = sigma_data_models.relationship('accounts', 'account_owner_user_guid', 'employees', 'employee_guid') %}
{% set rel_b = sigma_data_models.relationship('accounts', 'account_owner_user_guid', 'employees', 'manager_guid') %}
{% if rel_a.element_id == rel_b.element_id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: relationships differing only in to_column must not collide on element_id') %}
{% endif %}

{# element ids are frozen off a lowercased identifier path, so the same physical table bound
   with different db/schema casing must still freeze to the same id. #}
{% set table_casing_lower = sigma_data_models.table('casing_check_lower', identifier='accounts', schema='main', columns=['account_guid']) %}
{% set table_casing_upper = sigma_data_models.table('casing_check_upper', identifier='ACCOUNTS', schema='MAIN', columns=['account_guid']) %}
{% if table_casing_lower.element_id != table_casing_upper.element_id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: the same physical table must freeze to the same element_id regardless of db/schema/identifier casing') %}
{% endif %}

{# map_type must not misfire on types that merely contain a numeric-looking substring. #}
{% if sigma_data_models.map_type('INTERVAL DAY TO SECOND') == 'number' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: map_type('INTERVAL DAY TO SECOND') must not be bucketed as 'number'") %}
{% endif %}
{% if sigma_data_models.map_type('BIGINT') != 'number' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: map_type('BIGINT') must be bucketed as 'number'") %}
{% endif %}

{{ log('assert_sigma_spec: all assertions passed', info=true) }}
{% endmacro %}

{# Expected to fail: calling code should invoke these via `dbt run-operation` and treat a
   nonzero exit as success - a zero exit means the corresponding guard regressed. #}

{% macro assert_duplicate_column_rejected() %}
{% do sigma_data_models.table('dup_columns_check', identifier='accounts', columns=['account_guid', 'account_guid']) %}
{% endmacro %}

{% macro assert_duplicate_metric_rejected() %}
{% do sigma_data_models.table('dup_metrics_check', identifier='accounts', columns=['account_guid'], metrics=[
  sigma_data_models.metric('count_accounts', 'CountDistinct([account_guid])'),
  sigma_data_models.metric('count_accounts', 'Count([account_guid])'),
]) %}
{% endmacro %}

{% macro assert_duplicate_table_key_rejected() %}
{% do sigma_data_models.model(
  name='Duplicate Table Key Check',
  tables=[
    sigma_data_models.table('dup_key', identifier='accounts', columns=['account_guid']),
    sigma_data_models.table('dup_key', identifier='employees', columns=['employee_guid']),
  ],
) %}
{% endmacro %}

{% macro assert_unknown_relationship_from_rejected() %}
{% do sigma_data_models.model(
  name='Unknown Relationship From Check',
  tables=[sigma_data_models.table('accounts', identifier='accounts', columns=['account_guid'])],
  relationships=[('nonexistent_key', 'account_guid', 'accounts', 'account_guid')],
) %}
{% endmacro %}

{% macro assert_unknown_relationship_to_rejected() %}
{% do sigma_data_models.model(
  name='Unknown Relationship To Check',
  tables=[sigma_data_models.table('accounts', identifier='accounts', columns=['account_guid'])],
  relationships=[('accounts', 'account_guid', 'nonexistent_key', 'account_guid')],
) %}
{% endmacro %}

{% macro assert_invalid_primary_key_rejected() %}
{% do sigma_data_models.table('invalid_pk_check', identifier='accounts', primary_key='not_a_real_column', columns=['account_guid']) %}
{% endmacro %}
