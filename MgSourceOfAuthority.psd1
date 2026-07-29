@{
    RootModule        = 'MgSourceOfAuthority.psm1'
    ModuleVersion     = '0.1.0'
    GUID              = 'cdf60fd0-f8c9-48f4-9b36-0bbaf267ac57'
    Author            = 'Stefan Forsberg'
    Copyright         = '(c) 2026 Stefan Forsberg. All rights reserved.'
    Description       = 'Reads and changes the Microsoft Entra source of authority for users and groups through Microsoft Graph.'
    PowerShellVersion = '5.1'

    CompatiblePSEditions = @(
        'Desktop'
        'Core'
    )

    RequiredModules = @(
        'Microsoft.Graph.Authentication'
        'Microsoft.Graph.Users'
        'Microsoft.Graph.Groups'
    )

    FunctionsToExport = @(
        'Get-MgSourceOfAuthority'
        'Set-MgSourceOfAuthority'
        'Get-MgUserSourceOfAuthority'
        'Set-MgUserSourceOfAuthority'
        'Get-MgGroupSourceOfAuthority'
        'Set-MgGroupSourceOfAuthority'
        'Test-MgSourceOfAuthorityPermissions'
    )

    CmdletsToExport = @()
    VariablesToExport = @()

    AliasesToExport = @(
        'Get-EntraSourceOfAuthority'
        'Set-EntraSourceOfAuthority'
        'Get-EntraUserSourceOfAuthority'
        'Set-EntraUserSourceOfAuthority'
        'Get-EntraGroupSourceOfAuthority'
        'Set-EntraGroupSourceOfAuthority'
        'Test-EntraSourceOfAuthorityPermission'
    )

    PrivateData = @{
        PSData = @{
            Tags = @(
                'MicrosoftGraph'
                'MicrosoftEntra'
                'SourceOfAuthority'
                'HybridIdentity'
            )
            LicenseUri  = 'https://opensource.org/license/mit'
            ReleaseNotes = 'Initial public module structure.'
        }
    }
}
