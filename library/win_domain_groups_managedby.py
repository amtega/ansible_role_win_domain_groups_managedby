#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (C) 2019 AMTEGA - Xunta de Galicia
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# this is a windows documentation stub.  actual code lives in the .ps1
# file of the same name

ANSIBLE_METADATA = {'metadata_version': '1.1',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = r'''
---
module: win_domain_groups_managedby
version_added: '2.8.3'
short_description: Manages Windows Active Directory groups `managed by` field and ACL.
description:
     - Manages Windows Active Directory Organizational Units.
options:
        group = @{ type = "str"; required = $true }
        manager = @{ type = "str" }


  group:
    description:
      - Specifies the group to be provided by providing a SAM account name.
    type: str
    required: true

  manager:
    description:
      - Specifies the user or group that manages the object by providing a SAM account name.
    type: str

  manage_enabled:
    description:
        Indicates if the management of the group is is enabled.
          - C(yes) manager object is allowed to administer group content.
          - C(no) manager object can't administer group content.
    type: bool

  domain_server:
    description:
    - Specifies the Active Directory Domain Services instance to connect to.
    - Can be in the form of an FQDN or NetBIOS name.
    - If not specified then the value is based on the domain of the computer
      running PowerShell.
    type: str

  state:
    description:
      - When C(present), creates or updates the managedby group field.
      - When C(absent), removes the user managedby group field if it exists.
      - When C(query), retrieves the managedby group field details without making any changes.
    type: str
    choices: [ absent, present, query ]
    default: present

notes:

seealso:
- module: win_domain_group
- module: win_domain_user
author:
- Daniel Sánchez Fábregas (@Daniel-Sanchez-Fabregas)
'''

EXAMPLES = r'''
    - name: Clean test group ManagedBy
      win_domain_groups_managedby:
        group: app1_group
        domain_server: windows_dc_2
        state: absent

    - name: Set and enable test group ManagedBy
      win_domain_groups_managedby:
        group: app1_group
        manager: app_admin
        manage_enabled: Yes
        domain_server: "{{ test_domain_server }}"
        state: present

    - name: Query group ManagedBy status
      win_domain_groups_managedby:
        group: app1_group
        domain_server: windows_dc_2
        state: query
      register: win_domain_groups_managedby_query_result

    - debug:
        msg: >
            Group '{{ win_domain_groups_managedby_query_result.value.group }}' manager '{{
            win_domain_groups_managedby_query_result.value.manager }}'
            is {{ win_domain_groups_managedby_query_result.value.state }} and
            {% if win_domain_groups_managedby_query_result.value.manage_enabled %}
            {{ 'enabled' }}{% else %}{{ 'disabled' }}{% endif %}"
    # Output:
    # "Group 'app1_group' manager 'app_admin' is present and  enabled\"\n"
'''

RETURN = r'''
name:
    description: OU name
    returned: always
    type: str
    sample: my_ou
path:
    description: OU path
    returned: always
    type: str
    sample: OU=parent_OU,DC=company,DC=local
description:
    description: OU description
    returned: if state=present
    type: str
    sample: South office users
managed_by:
    description: User explicitly allowed to administer the OU
    returned: if state=present
    type: str
    sample: minion001
protected_from_accidental_deletion:
    description: Is the OU protected from accidental deletion
    returned: if state=present
    type: bool
    sample: No
state:
    description: The state of the OU object
    returned: always
    type: str
    sample: present
'''
