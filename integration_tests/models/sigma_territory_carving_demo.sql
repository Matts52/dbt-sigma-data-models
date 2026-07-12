{% set sigma_data_model = sigma_data_models.model(
    name='Territory Carving Demo',
    tables=[
      sigma_data_models.table('accounts', 'stg_accounts', primary_key='account_guid',
        columns=['account_guid', 'account_name', 'account_industry', 'account_owner_user_guid'],
        metrics={'count_accounts': 'CountDistinct([account_guid])'}),
      sigma_data_models.table('employees', 'stg_employees', primary_key='employee_guid',
        columns=['employee_guid', 'employee_name']),
    ],
    relationships=[
      ('accounts', 'account_owner_user_guid', 'employees', 'employee_guid'),
    ],
) %}

{{ sigma_data_models.materialize(sigma_data_model) }}

select 1
