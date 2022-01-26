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

Tests are based on [molecule with vagrant virtual machines](https://molecule.readthedocs.io/en/latest/installation.html).

```shell
cd amtega.win_domain_groups_managedby
molecule test --all
```

## License

Copyright (C) 2022 AMTEGA - Xunta de Galicia

This role is free software: you can redistribute it and/or modify it under the terms of:

GNU General Public License version 3, or (at your option) any later version; or the European Union Public License, either Version 1.2 or – as soon they will be approved by the European Commission ­subsequent versions of the EUPL.

This role is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details or European Union Public License for more details.

## Author Information

- Daniel Sánchez Fábregas.
