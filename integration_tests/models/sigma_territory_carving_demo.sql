{% set sigma_data_model = sigma_data_models.model(
    name='Territory Carving Demo',
    tables=[
      sigma_data_models.table('accounts', 'stg_accounts',
        page='Core',
        columns=[
          sigma_data_models.column('account_guid', display_name='Account ID',
            format=sigma_data_models.format('number', {'formatString': 'd'})),
          'account_name',
          'account_industry',
          'account_owner_user_guid',
          sigma_data_models.column('is_manufacturing', formula="[Account Industry] = 'Manufacturing'"),
        ],
        metrics=[
          sigma_data_models.metric('count_accounts', 'CountDistinct([Account Guid])',
            format=sigma_data_models.format('number', {'formatString': 'd'})),
        ],
        folders=[
          sigma_data_models.folder('Identifiers', columns=['account_guid', 'account_owner_user_guid']),
        ],
        filters=[
          sigma_data_models.filter('account_industry', kind='list', options={'mode': 'include', 'values': ['Manufacturing']}),
        ]),
      sigma_data_models.table('employees', 'stg_employees',
        page='Extensions',
        columns=['employee_guid', 'employee_name']),
    ],
    relationships=[
      ('accounts', 'account_owner_user_guid', 'employees', 'employee_guid'),
    ],
) %}

{{ sigma_data_models.materialize(sigma_data_model) }}

select 1
