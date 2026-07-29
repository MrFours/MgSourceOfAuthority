# MgSourceOfAuthority

`MgSourceOfAuthority` reads and changes the source-of-authority state for Microsoft Entra users and groups through Microsoft Graph.

> [!WARNING]
> This module uses the Microsoft Graph `/beta` endpoint. Beta APIs are subject to change and aren't supported by Microsoft for production use. Test changes carefully before using the module in an important tenant.

## Understanding the state

| `IsCloudManaged` | Meaning |
| --- | --- |
| `$true` | The object is cloud managed. Updates from on-premises Active Directory are blocked in the cloud. |
| `$false` | On-premises updates are allowed, and the on-premises directory can take over the object. |

See the Microsoft Graph documentation for the [`onPremisesSyncBehavior` resource](https://learn.microsoft.com/graph/api/resources/onpremisessyncbehavior?view=graph-rest-beta).

## Requirements

- Windows PowerShell 5.1 or PowerShell 7
- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.Users`
- `Microsoft.Graph.Groups`
- A Microsoft Entra work or school account
- The appropriate Microsoft Graph permissions and Microsoft Entra role

The source-of-authority API requires one or both of these permissions, depending on the resource type:

- `User-OnPremisesSyncBehavior.ReadWrite.All`
- `Group-OnPremisesSyncBehavior.ReadWrite.All`

Friendly lookups by user principal name or group display name can also require permissions that allow users or groups to be read. In delegated scenarios, Microsoft currently documents Hybrid Administrator as the least-privileged supported role for the source-of-authority operation.

## Installation

Place this directory in one of the paths returned by:

```powershell
$env:PSModulePath -split [IO.Path]::PathSeparator
```

Then import the module:

```powershell
Import-Module MgSourceOfAuthority
```

You can also import the manifest directly:

```powershell
Import-Module ./MgSourceOfAuthority/MgSourceOfAuthority.psd1
```

## Quick start

Connect with the permissions for the resource types you intend to manage:

```powershell
Connect-MgGraph -Scopes @(
    'User-OnPremisesSyncBehavior.ReadWrite.All'
    'Group-OnPremisesSyncBehavior.ReadWrite.All'
)
```

Read a user's current state:

```powershell
Get-MgUserSourceOfAuthority -UserPrincipalName 'alex@contoso.com'
```

Preview a change without applying it:

```powershell
Set-MgUserSourceOfAuthority `
    -UserPrincipalName 'alex@contoso.com' `
    -IsCloudManaged $true `
    -WhatIf
```

Apply the change:

```powershell
Set-MgUserSourceOfAuthority `
    -UserPrincipalName 'alex@contoso.com' `
    -IsCloudManaged $true
```

## Commands

Most users should start with the resource-specific commands:

- `Get-MgUserSourceOfAuthority`
- `Set-MgUserSourceOfAuthority`
- `Get-MgGroupSourceOfAuthority`
- `Set-MgGroupSourceOfAuthority`

The general and diagnostic commands are:

- `Get-MgSourceOfAuthority`
- `Set-MgSourceOfAuthority`
- `Test-MgSourceOfAuthorityPermissions`

Use PowerShell help to inspect syntax and parameter sets:

```powershell
Get-Command -Module MgSourceOfAuthority
Get-Help Get-MgUserSourceOfAuthority -Full
```

## Pipeline examples

```powershell
Get-MgUser -UserId 'alex@contoso.com' |
    Get-MgUserSourceOfAuthority
```

```powershell
Get-MgGroup -GroupId '00000000-0000-0000-0000-000000000000' |
    Set-MgGroupSourceOfAuthority -IsCloudManaged $true -WhatIf
```

## Entra aliases

For compatibility, the module exports `Get-Entra*`, `Set-Entra*`, and `Test-Entra*` aliases for the corresponding `Mg` functions. These aliases still use the Microsoft Graph PowerShell SDK internally.

## Safety

- Start setter commands with `-WhatIf`.
- Prefer immutable object IDs in automation.
- A group display name must resolve to exactly one group.
- Treat a source-of-authority change as an administrative operation and validate its downstream synchronization impact.

## Development

Run static analysis and tests before publishing a release:

```powershell
Invoke-ScriptAnalyzer -Path ./MgSourceOfAuthority -Recurse
Invoke-Pester ./MgSourceOfAuthority/tests
Test-ModuleManifest ./MgSourceOfAuthority/MgSourceOfAuthority.psd1
```

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
