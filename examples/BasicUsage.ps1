#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $UserPrincipalName,

    [Parameter()]
    [switch] $Apply
)

$modulePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'MgSourceOfAuthority.psd1'
Import-Module $modulePath -Force

$permission = 'User-OnPremisesSyncBehavior.ReadWrite.All'
if (-not (Test-MgSourceOfAuthorityPermissions -Type User)) {
    Connect-MgGraph -Scopes $permission
}

$current = Get-MgUserSourceOfAuthority -UserPrincipalName $UserPrincipalName
$current | Format-Table

$change = @{
    UserPrincipalName = $UserPrincipalName
    IsCloudManaged    = $true
}

if ($Apply) {
    Set-MgUserSourceOfAuthority @change
} else {
    Set-MgUserSourceOfAuthority @change -WhatIf
}
