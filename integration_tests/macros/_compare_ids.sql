{% macro _compare_ids() %}
{# Logs all frozen ids for a representative spec so the output can be compared across branches. #}
{% set t_accounts = sigma_data_models.table('accounts_cmp', identifier='accounts',
  columns=[
    'account_guid',
    'account_owner_user_guid',
    sigma_data_models.column('is_named_acme', formula="[Account Name] = 'Acme Corp'"),
  ],
  metrics=[sigma_data_models.metric('count_accounts', 'CountDistinct([Account Guid])')],
  folders=[sigma_data_models.folder('Identifiers', columns=['account_guid'])],
  filters=[sigma_data_models.filter('account_owner_user_guid', kind='list', options={'mode': 'include', 'values': ['e1']})],
) %}
{% set t_employees = sigma_data_models.table('employees_cmp', identifier='employees',
  columns=['employee_guid']) %}
{% set spec = sigma_data_models.model(
  name='ID Compare Check',
  tables=[t_accounts, t_employees],
  relationships=[('accounts_cmp', 'account_owner_user_guid', 'employees_cmp', 'employee_guid')],
) %}
{% set acct = spec.pages[0].elements[0] %}
{% set emp  = spec.pages[0].elements[1] %}
{{ log('table:accounts_cmp.id=' ~ acct.id, info=true) }}
{{ log('col:account_guid=' ~ acct.columns[0].id, info=true) }}
{{ log('col:account_owner_user_guid=' ~ acct.columns[1].id, info=true) }}
{{ log('col:is_named_acme=' ~ acct.columns[2].id, info=true) }}
{{ log('metric:count_accounts=' ~ acct.metrics[0].id, info=true) }}
{{ log('folder:Identifiers=' ~ acct.folders[0].id, info=true) }}
{{ log('filter:account_owner_user_guid.list=' ~ acct.filters[0].id, info=true) }}
{{ log('rel:sourceColumnId=' ~ acct.relationships[0]['keys'][0].sourceColumnId, info=true) }}
{{ log('rel:targetColumnId=' ~ acct.relationships[0]['keys'][0].targetColumnId, info=true) }}
{{ log('rel:targetElementId=' ~ acct.relationships[0].targetElementId, info=true) }}
{{ log('table:employees_cmp.id=' ~ emp.id, info=true) }}
{{ log('col:employee_guid=' ~ emp.columns[0].id, info=true) }}
{% endmacro %}
