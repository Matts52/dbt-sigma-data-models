{# Asserts the composed spec's *shape* matches Sigma's real data-model-as-code schema, as
   documented at https://help.sigmacomputing.com/docs/data-model-representation-example-library
   - not just that compilation doesn't error. See integration_tests/README.md for which
   specific Sigma examples each assertion corresponds to. #}
{% macro assert_sigma_spec() %}

{% set model_spec = sigma_data_models.model(
  name='Shape Check',
  tables=[
    sigma_data_models.table('accounts_shape_check', identifier='accounts',
      columns=[
        'account_guid',
        'account_owner_user_guid',
        sigma_data_models.column('is_named_acme', formula="[Account Name] = 'Acme Corp'"),
      ],
      metrics={'count_accounts': 'CountDistinct([Account Guid])'},
      folders=[sigma_data_models.folder('Identifiers', columns=['account_guid'])],
      filters=[sigma_data_models.filter('account_owner_user_guid', kind='list', options={'mode': 'include', 'values': ['e1']})]),
    sigma_data_models.table('employees_shape_check', identifier='employees',
      columns=['employee_guid']),
  ],
  relationships=[('accounts_shape_check', 'account_owner_user_guid', 'employees_shape_check', 'employee_guid')],
  folder_id='test-folder-id',
) %}

{# Top-level shape: dataModelId/name/folderId/schemaVersion/pages, matching the "create a data
   model from a code representation" request schema - see
   example-representation-data-model-with-a-single-table.md and
   create-a-data-model-from-a-code-representation.md. #}
{% if model_spec.schemaVersion != 1 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: schemaVersion must be 1') %}
{% endif %}
{% if model_spec.folderId != 'test-folder-id' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: folderId must pass through from the folder_id arg') %}
{% endif %}
{% if model_spec.pages | length != 1 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: model() must produce exactly one page') %}
{% endif %}
{% set page = model_spec.pages[0] %}
{% if page.id != '' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: page.id must be left blank ('') - Sigma assigns it on creation, per create-a-data-model-from-a-code-representation.md") %}
{% endif %}
{% if page.elements | length != 2 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: page must contain one element per table') %}
{% endif %}

{% set accounts_element = page.elements[0] %}
{% set employees_element = page.elements[1] %}

{# Table element shape: id/kind/source/columns/order, matching
   example-representation-data-model-with-a-single-table.md. Internal-only fields (`key`,
   `_column_ids`) must not leak into the emitted element. #}
{% if accounts_element.kind != 'table' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: table element kind must be 'table'") %}
{% endif %}
{% if 'key' in accounts_element or '_column_ids' in accounts_element or '_page' in accounts_element %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: internal-only fields (key, _column_ids, _page) must not appear in the emitted element') %}
{% endif %}
{% if accounts_element.source.kind != 'warehouse-table' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: source.kind must be 'warehouse-table'") %}
{% endif %}
{% if accounts_element.source.path | length != 3 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: source.path must be a 3-element [database, schema, identifier] list') %}
{% endif %}
{% if accounts_element.source.path[2] != 'accounts' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: source.path[2] must be the bound identifier') %}
{% endif %}

{# Table element name: defaults to titleize(key), or explicit display_name when supplied. #}
{% if accounts_element.name != 'Accounts Shape Check' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: table name must default to titleize(key), got '" ~ accounts_element.name ~ "'") %}
{% endif %}
{% set named_table = sigma_data_models.table('named_check', identifier='accounts', columns=['account_guid'], display_name='Custom Label') %}
{% if named_table.name != 'Custom Label' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: table display_name must pass through as name, got '" ~ named_table.name ~ "'") %}
{% endif %}

{# Passthrough column shape: {id, formula} only - no `name` key, matching
   example-representation-data-model-with-a-single-table.md. #}
{% set passthrough_column = accounts_element.columns[0] %}
{% if passthrough_column.keys() | list | sort != ['formula', 'id'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a passthrough column must have exactly {id, formula}, got ' ~ (passthrough_column.keys() | list)) %}
{% endif %}
{% if passthrough_column.formula != '[accounts/Account Guid]' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: a passthrough column's formula must default to '[identifier/Titleized Name]', got " ~ passthrough_column.formula) %}
{% endif %}

{# Calculated column shape: {id, formula, name}, matching
   example-representation-data-model-with-a-table-and-a-calculated-column.md. #}
{% set calculated_column = accounts_element.columns[2] %}
{% if calculated_column.keys() | list | sort != ['formula', 'id', 'name'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a calculated column must have exactly {id, formula, name}, got ' ~ (calculated_column.keys() | list)) %}
{% endif %}
{% if calculated_column.name != 'Is Named Acme' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a calculated column name must default to a title-cased version of its key') %}
{% endif %}

{# display_name-only passthrough: must emit {id, formula, name} with the given display_name,
   not silently fall back to titleize(column.name). #}
{% set dn_table = sigma_data_models.table('display_name_col_check', identifier='accounts', columns=[
  sigma_data_models.column('account_owner_user_guid', display_name='Account Owner ID')
]) %}
{% set dn_col = dn_table.columns[0] %}
{% if dn_col.keys() | list | sort != ['formula', 'id', 'name'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a display_name-only column must have exactly {id, formula, name}, got ' ~ (dn_col.keys() | list)) %}
{% endif %}
{% if dn_col.name != 'Account Owner ID' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: a display_name-only column must use the display_name as its name, got '" ~ dn_col.name ~ "'") %}
{% endif %}
{% set expected_dn_formula = '[' ~ dn_table.source.path[2] ~ '/' ~ sigma_data_models.titleize('account_owner_user_guid') ~ ']' %}
{% if dn_col.formula != expected_dn_formula %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: a display_name-only column's formula must still auto-generate to '[identifier/Titleized Name]', got " ~ dn_col.formula) %}
{% endif %}

{# order must be exactly the column ids, in declaration order. #}
{% set expected_order = [] %}
{% for c in accounts_element.columns %}
  {% do expected_order.append(c.id) %}
{% endfor %}
{% if accounts_element.order != expected_order %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: order must be exactly the column ids in declaration order') %}
{% endif %}

{# Metric shape: {id, formula, name}, matching
   example-representation-data-model-with-a-table-and-a-metric.md. Metrics only appear on a
   table when at least one was supplied. #}
{% if 'metrics' not in employees_element %}
  {# employees_shape_check has no metrics - correctly omitted, not an empty list. #}
{% else %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a table with no metrics must omit the `metrics` key entirely') %}
{% endif %}
{% set metric = accounts_element.metrics[0] %}
{% if metric.keys() | list | sort != ['formula', 'id', 'name'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a metric must have exactly {id, formula, name}, got ' ~ (metric.keys() | list)) %}
{% endif %}
{% if metric.formula != 'CountDistinct([Account Guid])' or metric.name != 'Count Accounts' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: metric formula/name did not pass through correctly') %}
{% endif %}

{# Folder shape: {id, name, items}, matching example-representation-data-model-with-a-folder.md. #}
{% set folder = accounts_element.folders[0] %}
{% if folder.keys() | list | sort != ['id', 'items', 'name'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a folder must have exactly {id, name, items}, got ' ~ (folder.keys() | list)) %}
{% endif %}
{% if folder['items'] != [passthrough_column.id] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: folder.items must be the ids of its member columns') %}
{% endif %}

{# Filter shape: {id, columnId, kind, ...kind-specific fields verbatim}, matching
   example-representation-data-model-with-filters.md. #}
{% set filter = accounts_element.filters[0] %}
{% if filter.keys() | list | sort != ['columnId', 'id', 'kind', 'mode', 'values'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a list filter must have exactly {id, columnId, kind, mode, values}, got ' ~ (filter.keys() | list)) %}
{% endif %}
{% if filter.columnId != accounts_element.columns[1].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: filter.columnId must be the resolved column id') %}
{% endif %}
{% if filter.kind != 'list' or filter.mode != 'include' or filter['values'] != ['e1'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: filter kind-specific fields did not pass through verbatim') %}
{% endif %}

{# Relationship shape: nests inside the *source* table's element (not at the model level), as
   {id, targetElementId, keys: [{sourceColumnId, targetColumnId}], name}, matching
   example-representation-data-model-with-a-table-and-a-relationship.md. #}
{% if 'relationships' in employees_element %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: relationships must nest under the source (from) table, not the target (to) table') %}
{% endif %}
{% set relationship = accounts_element.relationships[0] %}
{% if relationship.keys() | list | sort != ['id', 'keys', 'name', 'targetElementId'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a relationship must have exactly {id, targetElementId, keys, name}, got ' ~ (relationship.keys() | list)) %}
{% endif %}
{% if relationship.targetElementId != employees_element.id %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: relationship.targetElementId must be the target table's real element id") %}
{% endif %}
{% if relationship['keys'] | length != 1 or relationship['keys'][0].keys() | list | sort != ['sourceColumnId', 'targetColumnId'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: relationship.keys must be a list of {sourceColumnId, targetColumnId}') %}
{% endif %}
{% if relationship['keys'][0].sourceColumnId != accounts_element.columns[1].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: relationship sourceColumnId must be the resolved from_column id') %}
{% endif %}
{% if relationship['keys'][0].targetColumnId != employees_element.columns[0].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: relationship targetColumnId must be the resolved to_column id') %}
{% endif %}
{% set expected_rel_name = sigma_data_models.titleize('accounts_shape_check') ~ ' → ' ~ sigma_data_models.titleize('employees_shape_check') %}
{% if relationship.name != expected_rel_name %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: relationship.name must default to titleize(from) ~ ' → ' ~ titleize(to) when no name is supplied, got '" ~ relationship.name ~ "'") %}
{% endif %}

{# freeze_id determinism: identical inputs must yield identical ids across independent calls. #}
{% set model_spec_again = sigma_data_models.model(
  name='Shape Check',
  tables=[
    sigma_data_models.table('accounts_shape_check', identifier='accounts', columns=['account_guid', 'account_owner_user_guid']),
    sigma_data_models.table('employees_shape_check', identifier='employees', columns=['employee_guid']),
  ],
  relationships=[('accounts_shape_check', 'account_owner_user_guid', 'employees_shape_check', 'employee_guid')],
) %}
{% if model_spec_again.pages[0].elements[0].id != accounts_element.id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: table element ids are not deterministic across identical calls') %}
{% endif %}
{% if model_spec_again.pages[0].elements[0].columns[0].id != passthrough_column.id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: column ids are not deterministic across identical calls') %}
{% endif %}

{# Leaving `columns` empty auto-populates passthrough columns from the live relation - only
   possible under `dbt run-operation`/`dbt run`/`dbt compile` (execute=True), never `dbt parse`. #}
{% set auto_populated_table = sigma_data_models.table('accounts_auto_populate_check', identifier='accounts') %}
{% if auto_populated_table.columns | length == 0 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: leaving columns empty must auto-populate from the live relation, got none') %}
{% endif %}
{% set auto_populated_names = auto_populated_table._column_ids.keys() | list %}
{% if 'account_guid' not in auto_populated_names or 'account_owner_user_guid' not in auto_populated_names %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: auto-populated columns must include the real columns on the relation, got ' ~ auto_populated_names) %}
{% endif %}
{% if auto_populated_table.columns[0].keys() | list | sort != ['formula', 'id'] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: an auto-populated column must still be a plain passthrough column ({id, formula}), got ' ~ (auto_populated_table.columns[0].keys() | list)) %}
{% endif %}

{# Duplicate `key`s across different sigma.table() calls must not collide on element_id -
   `key` is a local wiring label, ids are frozen off the physical identifier instead. #}
{% set table_a = sigma_data_models.table('shared_key', identifier='accounts', columns=['account_guid']) %}
{% set table_b = sigma_data_models.table('shared_key', identifier='employees', columns=['employee_guid']) %}
{% if table_a.id == table_b.id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: tables sharing a key but bound to different identifiers must not collide on element id') %}
{% endif %}

{# element ids are frozen off a lowercased identifier path (and `key`, held constant here), so
   the same key/physical-table pair must still freeze to the same id regardless of db/schema
   casing. #}
{% set table_casing_lower = sigma_data_models.table('casing_check', identifier='accounts', schema='main', columns=['account_guid']) %}
{% set table_casing_upper = sigma_data_models.table('casing_check', identifier='ACCOUNTS', schema='MAIN', columns=['account_guid']) %}
{% if table_casing_lower.id != table_casing_upper.id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: the same key/physical table must freeze to the same id regardless of db/schema/identifier casing') %}
{% endif %}

{# self-joins: the same physical table referenced twice under different `key`s in one model
   must get distinct ids everywhere (table, and its columns), not collide. #}
{% set self_join_spec = sigma_data_models.model(
  name='Self Join Check',
  tables=[
    sigma_data_models.table('employees_self_join', identifier='employees', columns=['employee_guid']),
    sigma_data_models.table('managers_self_join', identifier='employees', columns=['employee_guid']),
  ],
) %}
{% set self_join_elements = self_join_spec.pages[0].elements %}
{% if self_join_elements[0].id == self_join_elements[1].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: the same physical table referenced twice under different keys (a self-join) must not collide on element id') %}
{% endif %}
{% if self_join_elements[0].columns[0].id == self_join_elements[1].columns[0].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: a self-joined table\'s columns must not collide on id either') %}
{% endif %}

{# Multi-page: tables with page= set must appear on separate pages in first-appearance order;
   tables with no page= default to the first page (named by page_name or model name). #}
{% set multi_page_spec = sigma_data_models.model(
  name='Multi Page Check',
  tables=[
    sigma_data_models.table('accounts_page_check', identifier='accounts',
      columns=['account_guid', 'account_owner_user_guid'],
      page='Core'),
    sigma_data_models.table('employees_page_check', identifier='employees',
      columns=['employee_guid'],
      page='Extensions'),
  ],
  relationships=[('accounts_page_check', 'account_owner_user_guid', 'employees_page_check', 'employee_guid')],
) %}
{% if multi_page_spec.pages | length != 2 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: tables with distinct page= values must produce one page per unique page name') %}
{% endif %}
{% if multi_page_spec.pages[0].name != 'Core' or multi_page_spec.pages[1].name != 'Extensions' %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: pages must be emitted in first-appearance order of page= values') %}
{% endif %}
{% if multi_page_spec.pages[0].elements | length != 1 or multi_page_spec.pages[1].elements | length != 1 %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: each table must appear on its assigned page only') %}
{% endif %}
{# Cross-page relationship: resolves correctly even when source and target are on different pages. #}
{% if 'relationships' not in multi_page_spec.pages[0].elements[0] %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: cross-page relationship must still nest under the source (from) table element') %}
{% endif %}
{% if multi_page_spec.pages[0].elements[0].relationships[0].targetElementId != multi_page_spec.pages[1].elements[0].id %}
  {% do exceptions.raise_compiler_error('assert_sigma_spec: cross-page relationship.targetElementId must be the target element id, even when on a different page') %}
{% endif %}

{# Default page: tables without page= land on a page named page_name or model name. #}
{% set default_page_spec = sigma_data_models.model(
  name='Default Page Check',
  page_name='My Page',
  tables=[
    sigma_data_models.table('accounts_default_page', identifier='accounts', columns=['account_guid']),
  ],
) %}
{% if default_page_spec.pages | length != 1 or default_page_spec.pages[0].name != 'My Page' %}
  {% do exceptions.raise_compiler_error("assert_sigma_spec: tables without page= must default to page_name (or model name when page_name is unset)") %}
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
  sigma_data_models.metric('count_accounts', 'CountDistinct([Account Guid])'),
  sigma_data_models.metric('count_accounts', 'Count([Account Guid])'),
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

{% macro assert_unknown_relationship_column_rejected() %}
{% do sigma_data_models.model(
  name='Unknown Relationship Column Check',
  tables=[
    sigma_data_models.table('accounts', identifier='accounts', columns=['account_guid']),
    sigma_data_models.table('employees', identifier='employees', columns=['employee_guid']),
  ],
  relationships=[('accounts', 'not_a_real_column', 'employees', 'employee_guid')],
) %}
{% endmacro %}

{% macro assert_unknown_folder_column_rejected() %}
{% do sigma_data_models.table('bad_folder_check', identifier='accounts', columns=['account_guid'],
  folders=[sigma_data_models.folder('Identifiers', columns=['not_a_real_column'])]) %}
{% endmacro %}

{% macro assert_unknown_filter_column_rejected() %}
{% do sigma_data_models.table('bad_filter_check', identifier='accounts', columns=['account_guid'],
  filters=[sigma_data_models.filter('not_a_real_column', kind='list', options={'mode': 'include', 'values': ['x']})]) %}
{% endmacro %}

{% macro assert_nonexistent_relation_rejected() %}
{% do sigma_data_models.table('typo_check', identifier='accounts_typo') %}
{% endmacro %}

{% macro assert_duplicate_folder_rejected() %}
{% do sigma_data_models.table('dup_folder_check', identifier='accounts', columns=['account_guid', 'account_owner_user_guid'],
  folders=[
    sigma_data_models.folder('Identifiers', columns=['account_guid']),
    sigma_data_models.folder('Identifiers', columns=['account_owner_user_guid']),
  ]) %}
{% endmacro %}

{% macro assert_duplicate_filter_rejected() %}
{% do sigma_data_models.table('dup_filter_check', identifier='accounts', columns=['account_guid'],
  filters=[
    sigma_data_models.filter('account_guid', kind='list', options={'mode': 'include', 'values': ['a1']}),
    sigma_data_models.filter('account_guid', kind='list', options={'mode': 'exclude', 'values': ['a2']}),
  ]) %}
{% endmacro %}

{% macro assert_duplicate_relationship_rejected() %}
{% do sigma_data_models.model(
  name='Duplicate Relationship Check',
  tables=[
    sigma_data_models.table('accounts', identifier='accounts', columns=['account_guid', 'account_owner_user_guid']),
    sigma_data_models.table('employees', identifier='employees', columns=['employee_guid']),
  ],
  relationships=[
    ('accounts', 'account_owner_user_guid', 'employees', 'employee_guid'),
    ('accounts', 'account_owner_user_guid', 'employees', 'employee_guid'),
  ],
) %}
{% endmacro %}

{% macro assert_filter_options_reserved_key_rejected() %}
{% do sigma_data_models.table('filter_reserved_key_check', identifier='accounts', columns=['account_guid'],
  filters=[sigma_data_models.filter('account_guid', kind='list', options={'kind': 'CLOBBERED'})]) %}
{% endmacro %}

{% macro assert_alphanumeric_column_rejected() %}
{% do sigma_data_models.table('alphanumeric_column_check', identifier='accounts', columns=['active_paid_users_l30_days']) %}
{% endmacro %}
