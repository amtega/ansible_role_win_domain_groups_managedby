# Ansible win_domain_groups_managedby role

This is an [Ansible](http://www.ansible.com) role which setup `managed by` field and ACL in windows active directory groups.

## Role Variables

A list of all the default variables for this role is available in `defaults/main.yml`.

## Modules

The role provides these modules:

- `win_domain_groups_managedby`: which setup `managed by` field and ACL in a windows active directory single group.


- `main.yml`: tests main use cases of the role and library.

## Usage

This is an example playbook:

```yaml
---

  - hosts: windows_ad_computer
    roles:
      - role: amtega.win_domain_groups_managedby
    vars:
      win_domain_groups_managedby_defaults:
        domain_server: windows_dc_2

      win_domain_groups_managedby:

        - group: app1_group
          manager: app_admin
          manage_enabled: yes
          state: present

        - group: app2_group
          manager: app_admin
          manage_enabled: no
          state: present

        - group: app3_group
          manager: app_admin
          state: absent
```

## Testing

To run test you must pass in the command line the variable `win_domain_groups_managedby_tests_host` pointing to a windows host fulfilling the ansible requirements documented in https://docs.ansible.com/ansible/latest/user_guide/windows_setup.html. Also, you must define in the inventory for this host the necessary variables to connect.

Additionally the tests requires the following set of variables that can be defined in the inventory or passed in the command line:

- `win_domain_groups_managedby_ou`: OU where the test groups reside.
- `win_domain_groups_managedby_group`: Group to be managed during the tests
- `win_domain_groups_managedby_group2`: Other group to be managed during the tests
- `win_domain_groups_managedby_manager`: Manager of the test group
- `win_domain_groups_managedby_manager2`: Other manager of the test group
- `win_domain_groups_managedby_domain_server`: Specifies the domain server where the Active Directory is modified.

One way to provide all the previous information is calling the testing playbook passing the host to use and an additional vault inventory plus the default one provided for testing, as it's show in this example:

```shell
$ cd amtega.win_domain_groups/tests
$ ansible-playbook main.yml -e "win_domain_groups_managedby_tests_host=test_host" -i inventory -i ~/mycustominventory.yml --vault-id myvault@prompt
```

## License

Copyright (C) 2019 AMTEGA - Xunta de Galicia

This role is free software: you can redistribute it and/or modify it under the terms of:

GNU General Public License version 3, or (at your option) any later version; or the European Union Public License, either Version 1.2 or – as soon they will be approved by the European Commission ­subsequent versions of the EUPL.

This role is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details or European Union Public License for more details.

## Author Information

- Daniel Sánchez Fábregas.
