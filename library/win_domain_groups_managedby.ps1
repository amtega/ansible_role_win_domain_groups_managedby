#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
Set-StrictMode -Version 2.0

$spec = @{
    options = @{
        domain_server = @{ type = "str" }
        group = @{ type = "str"; required = $true }
        manager = @{ type = "str" }
        manage_enabled = @{ type = "bool" }
        state = @{ type = "str"; choices = "absent", "present", "query"; default = "present" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$domain_server = $module.Params.domain_server
$group = $module.Params.group
$manager = $module.Params.manager
$manage_enabled = $module.Params.manage_enabled
$state = $module.Params.state

$extra_args = @{}
If ($null -ne $domain_server) {
  $extra_args.Server = $domain_server
  $server_drive = "SERVER"
  Try {
    Import-Module ActiveDirectory
  }
  Catch {
     Fail-Json $result "Failed to import ActiveDirectory PowerShell module."
  }
  New-PSDrive -Name $server_drive -PSProvider ActiveDirectory -Server $domain_server -Scope Global -root "//RootDSE/" | Out-Null
} Else {
  $server_drive = "AD"
}

If ($manager -eq $null -and $state -eq 'present') {
    $module.FailJson("Parameter 'manager' is required when state='$state'")
}
If ($manager -ne $null -and $state -ne 'present') {
    $module.FailJson("Parameter 'manager' must be empty when state='$state'")
}

If ($manager -eq $null -and $manage_enabled -eq $true) {
  $module.FailJson("Parameter 'manager' is required when manage_enabled=Yes")
}

If ($manage_enabled -eq $null) {
  If ($state -eq 'present') {
    $manage_enabled = $true
  } ElseIf ($state -eq 'absent') {
    $manage_enabled = $false
  }
} Else { # $manage_enabled != $null
  If ($state -eq 'query') {
    $module.FailJson("Parameter 'manage_enabled' must be empty when state='$state'")
  }
}

# $module.Result._debug = @()
# Function Set-AnsibleDebug($linea) { $module.Result._debug += "[$($MyInvocation.ScriptLineNumber)] $linea" }

# ------------------------------------------------------------------------------
Function Get-ManagerObject($manager_name) {
  If ($null -eq $manager_name) { return $null }
  Try {
    $m_obj = Get-ADObject -Filter "name -eq '$manager_name'"
    # $manager_name = $m_obj.DistinguishedName -replace 'CN=([^=]*),.*$','$1'
    $manager_object = Invoke-Expression "Get-ad$($m_obj.ObjectClass) '$($m_obj.DistinguishedName)'"
  } Catch {
    $module.FailJson("Failed reading manager $manager_name data: $($_.Exception.Message)", $_)
  }
  return $manager_object
}

# ------------------------------------------------------------------------------
Function Get-CurrentState($desired_state) {

  $group_object = Try {
      Get-AdGroup `
        -Identity $desired_state.group `
        -Properties Name,DistinguishedName,ManagedBy `
         @extra_args
      # } Catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
      } Catch {
        $module.FailJson("Failed reading group $($desired_state.group) data: $($_.Exception.Message)", $_)
      }

  If ($null -eq $group_object.ManagedBy) {
    $manager_object = $null
    $manager = $null
    $state = "absent"
  } Else {
    $manager_name = $group_object.ManagedBy -replace 'CN=([^=]*),.*$','$1'
    $manager_object = Get-ManagerObject $manager_name
    $manager = $manager_object.Name
    $state = "present"
  }

  $manage_enabled = Get-GroupManagedEnabled $group_object $manager_object

  $initial_state = [ordered]@{
    group = $desired_state.group
    manager = $manager
    manage_enabled = $manage_enabled
    state = $state
    _ = @{ # HACK: Private values
        group_object = $group_object
        manager_object = $manager_object
      }
  }

  return $initial_state
}

# ------------------------------------------------------------------------------
Function Get-GroupManagedEnabled($group, $manager) {
  If ($manager) {
    $manage_enabled = Try {
        If((Get-Acl -Path "AD:\$($group.DistinguishedName)").sddl.split(")(") `
          | Where-Object{$_ -match $manager.SID.value }) { $True } Else { $False }
      } Catch { $null }
  } Else {
    $manage_enabled = $False
  }
  return $manage_enabled
}


# ------------------------------------------------------------------------------
Function Set-GroupManagedBy($group, $manager) {
  If ($null -eq $manager) {
    Try {
      Set-ADGroup `
        -Identity $desired_state.group `
        -Clear ManagedBy `
        -WhatIf:$module.CheckMode `
        @extra_args
    } Catch {
      $module.FailJson("Failed to clear ManagedBy attribute in group $($group.Name): $($_.Exception.Message)", $_)
    }
  } Else {
    Try {
      Set-ADGroup `
        -Identity $desired_state.group `
        -ManagedBy $manager `
        -WhatIf:$module.CheckMode `
        @extra_args
    } Catch {
      $module.FailJson("Failed to set ManagedBy attribute in group $($group.Name): $($_.Exception.Message)", $_)
    }
  }
  $module.Result.changed = $true
}

# ------------------------------------------------------------------------------
Function Set-GroupManagedEnabled($group, $manager, $manage_enabled) {

  If ($null -eq $manager) {
    $module.FailJson("Error: Can't enable a unespecified manager")
  }

  $extendedrightsmap = @{}
  Try {
    $rootdse = Get-ADRootDSE @extra_args
    Get-ADObject -SearchBase ($rootdse.ConfigurationNamingContext) `
      -LDAPFilter "(&(objectclass=controlAccessRight)(rightsguid=*))" `
      -Properties displayName,rightsGuid `
      @extra_args `
    | ForEach-Object {$extendedrightsmap[$_.displayName]=[System.GUID]$_.rightsGuid}
  } Catch {
    $module.FailJson("Failed reading extended permission descriptions: $($_.Exception.Message)", $_)
  }

  Try {
    $acl = Get-Acl -Path "$($server_drive):\$($group.DistinguishedName)"
  } Catch {
    $module.FailJson("Failed reading ACL in group $($group.DistinguishedName): $($_.Exception.Message)", $_)
  }
  $permission =[System.DirectoryServices.ActiveDirectoryRights]::WriteProperty -bor [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight
  $group_SID = [System.Security.Principal.SecurityIdentifier]$($manager.SID)
  $access_rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $group_SID,$permission,"Allow",$extendedrightsmap["Add/Remove self as member"]
  If ($manage_enabled) {
    $acl.AddAccessRule($access_rule)
  } Else {
    $acl.RemoveAccessRule($access_rule) | Out-Null
  }

  Try {
    Set-ACL -ACLObject $acl -Path "$($server_drive):\$($group.DistinguishedName)" -WhatIf:$module.CheckMode
  } Catch {
    $module.FailJson("Failed setting ACL in group $($group.DistinguishedName): $($_.Exception.Message)", $_)
  }
  $module.Result.changed = $true
}

# ------------------------------------------------------------------------------
Function ConvertTo-SerializedState($state) {
  return @(
    $state.GetEnumerator() | ForEach-Object {
      If ($null -ne $_.Value) {
        "$($_.Name): $($_.Value)`n"
      } else {
        ""
      }
    } ) -join ''
}

# ··············································································

$desired_state = [ordered]@{
  group = $group
  manager = $manager
  manage_enabled = $manage_enabled
  state = $state
  _ = @{ # HACK: Private values
      # group_object = $group_object
      manager_object = Get-ManagerObject $manager
    }
}

$initial_state = Get-CurrentState $desired_state

If ($desired_state.state -eq "query") {
  $initial_state.Remove("_") # Hack (cleaning previous hack)
  $module.Result.value = $initial_state
  $module.ExitJson()
}


If (($initial_state.manage_enabled -and -not $desired_state.manage_enabled) -or (($initial_state.manager -ne $desired_state.manager)  -and ($initial_state.manage_enabled -and $desired_state.manage_enabled))) {
  Set-GroupManagedEnabled $initial_state._.group_object $initial_state._.manager_object $false
}
If (($null -ne $initial_state.manager) -and ($initial_state.manager -ne $desired_state.manager)) {
  Set-GroupManagedBy $initial_state._.group_object $null
}

If (($null -ne $desired_state.manager) -and ($initial_state.manager -ne $desired_state.manager)) {
  Set-GroupManagedBy $initial_state._.group_object $desired_state.manager
}

If ((-not $initial_state.manage_enabled -and $desired_state.manage_enabled) `
    -or (($initial_state.manager -ne $desired_state.manager) `
         -and ($initial_state.manage_enabled -and $desired_state.manage_enabled))) {
  Set-GroupManagedEnabled $initial_state._.group_object $desired_state._.manager_object $true
}

#------------------------------------------------------------------

$initial_state.Remove("_") # Hack (cleaning previous hack)

If ($module.Result.changed) {
  $final_state = Get-CurrentState $desired_state
  # $final_state.Remove("_") # Hack (cleaning previous hack)
} else {
  $final_state = $initial_state
}

if ($module.CheckMode) {
  $after_state  = $desired_state
} else {
  $after_state  = $final_state
}

$after_state.Remove("_") # Hack (cleaning previous hack)
$module.Result.value = $after_state

$module.Diff.before = ConvertTo-SerializedState $initial_state
$module.Diff.after  = ConvertTo-SerializedState $after_state

$module.ExitJson()
