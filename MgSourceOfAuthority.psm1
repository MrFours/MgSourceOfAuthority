Function Test-MgSourceOfAuthorityPermissions {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group')]
        [string] $Type
    )

    $context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $context) {
        return $false
    }

    $permission = '{0}-OnPremisesSyncBehavior.ReadWrite.All' -f $Type
    return $context.Scopes -contains $permission
}

Function Get-MgSourceOfAuthority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [guid] $Id,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group')]
        [string] $Type
    )

    $permission = '{0}-OnPremisesSyncBehavior.ReadWrite.All' -f $Type
    if (-not (Test-MgSourceOfAuthorityPermissions -Type $Type)) {
        Write-Error "Not connected with the required permission '$permission'. Run Connect-MgGraph -Scopes '$permission'."
        return
    }

    $resourceType = $Type.ToLowerInvariant()
    $request = @{
        Method      = 'GET'
        Uri         = '/v1.0/{0}s/{1}/onPremisesSyncBehavior' -f $resourceType, $Id
        ErrorAction = 'Stop'
    }

    try {
        $response = Invoke-MgGraphRequest @request
    } catch {
        Write-Error "Unable to retrieve the source of authority for $resourceType '$Id': $($_.Exception.Message)"
        return
    }

    # The endpoint has returned both a direct object and a value wrapper,
    # so handle either response shape.
    if ($response -is [System.Collections.IDictionary] -and $response.Contains('value')) {
        $behavior = $response['value']
    } elseif ($response.PSObject.Properties['value']) {
        $behavior = $response.value
    } else {
        $behavior = $response
    }

    if ($behavior -is [System.Collections.IDictionary]) {
        $isCloudManaged = $behavior['isCloudManaged']
    } else {
        $isCloudManaged = $behavior.isCloudManaged
    }

    [pscustomobject][ordered]@{
        Id             = $Id
        Type           = $Type
        IsCloudManaged = $isCloudManaged
    }
}

Function Set-MgSourceOfAuthority {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory)]
        [guid] $Id,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'Group')]
        [string] $Type,

        [Parameter(Mandatory)]
        [bool] $IsCloudManaged
    )

    $permission = '{0}-OnPremisesSyncBehavior.ReadWrite.All' -f $Type
    if (-not (Test-MgSourceOfAuthorityPermissions -Type $Type)) {
        Write-Error "Not connected with the required permission '$permission'. Run Connect-MgGraph -Scopes '$permission'."
        return
    }

    $resourceType = $Type.ToLowerInvariant()

    try {
        $current = Get-MgSourceOfAuthority -Id $Id -Type $Type -ErrorAction Stop
    } catch {
        Write-Error "Unable to retrieve the current source of authority for $resourceType '$Id': $($_.Exception.Message)"
        return
    }

    if (-not $current) {
        Write-Error "Unable to retrieve the current source of authority for $resourceType '$Id'."
        return
    }

    if ($current.IsCloudManaged -eq $IsCloudManaged) {
        $state = if ($IsCloudManaged) { 'cloud managed' } else { 'managed on-premises' }
        Write-Warning "The source of authority for $resourceType '$Id' is already $state."
        return
    }

    $targetState = if ($IsCloudManaged) { 'cloud managed' } else { 'managed on-premises' }
    if (-not $PSCmdlet.ShouldProcess("$Type '$Id'", "Set source of authority to $targetState")) {
        return
    }

    $request = @{
        Method      = 'PATCH'
        Uri         = '/v1.0/{0}s/{1}/onPremisesSyncBehavior' -f $resourceType, $Id
        ContentType = 'application/json'
        Body        = @{
            '@odata.type'   = '#microsoft.graph.onPremisesSyncBehavior'
            isCloudManaged = $IsCloudManaged
        }
        ErrorAction = 'Stop'
    }

    try {
        Invoke-MgGraphRequest @request | Out-Null

        [pscustomobject][ordered]@{
            Id             = $Id
            Type           = $Type
            IsCloudManaged = $IsCloudManaged
        }
    } catch {
        Write-Error "Unable to set IsCloudManaged=$IsCloudManaged for $resourceType '$Id': $($_.Exception.Message)"
    }
}

Function Get-MgUserSourceOfAuthority {
    [CmdletBinding(DefaultParameterSetName = 'User')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'User', ValueFromPipeline)]
        [ValidateScript({ $null -ne $_.Id })]
        [object] $User,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [guid] $Id,

        [Parameter(Mandatory, ParameterSetName = 'Upn')]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Id' {
                try {
                    $User = Get-MgUser -UserId $Id -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve user with Id '$Id': $($_.Exception.Message)"
                    return
                }
            }
            'Upn' {
                try {
                    $User = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve user with UserPrincipalName '$UserPrincipalName': $($_.Exception.Message)"
                    return
                }
            }
        }

        Get-MgSourceOfAuthority -Id $User.Id -Type User
    }
}

Function Get-MgGroupSourceOfAuthority {
    [CmdletBinding(DefaultParameterSetName = 'Group')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Group', ValueFromPipeline)]
        [ValidateScript({ $null -ne $_.Id })]
        [object] $Group,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [guid] $Id,

        [Parameter(Mandatory, ParameterSetName = 'DisplayName')]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Id' {
                try {
                    $Group = Get-MgGroup -GroupId $Id -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve group with Id '$Id': $($_.Exception.Message)"
                    return
                }
            }
            'DisplayName' {
                try {
                    $escapedDisplayName = $DisplayName.Replace("'", "''")
                    $Group = @(Get-MgGroup -Filter "displayName eq '$escapedDisplayName'" -All -ErrorAction Stop)
                } catch {
                    Write-Error "Unable to retrieve group with DisplayName '$DisplayName': $($_.Exception.Message)"
                    return
                }

                if ($Group.Count -eq 0) {
                    Write-Warning "No group found with DisplayName '$DisplayName'."
                    return
                }
                if ($Group.Count -gt 1) {
                    Write-Warning "Multiple groups found with DisplayName '$DisplayName'; use Id to specify the group."
                    return
                }

                $Group = $Group[0]
            }
        }

        Get-MgSourceOfAuthority -Id $Group.Id -Type Group
    }
}

Function Set-MgUserSourceOfAuthority {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'User')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'User', ValueFromPipeline)]
        [ValidateScript({ $null -ne $_.Id })]
        [object] $User,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [guid] $Id,

        [Parameter(Mandatory, ParameterSetName = 'Upn')]
        [ValidateNotNullOrEmpty()]
        [string] $UserPrincipalName,

        [Parameter(Mandatory)]
        [bool] $IsCloudManaged
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Id' {
                try {
                    $User = Get-MgUser -UserId $Id -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve user with Id '$Id': $($_.Exception.Message)"
                    return
                }
            }
            'Upn' {
                try {
                    $User = Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve user with UserPrincipalName '$UserPrincipalName': $($_.Exception.Message)"
                    return
                }
            }
        }

        $targetState = if ($IsCloudManaged) { 'cloud managed' } else { 'managed on-premises' }
        if ($PSCmdlet.ShouldProcess("User '$($User.Id)'", "Set source of authority to $targetState")) {
            Set-MgSourceOfAuthority -Id $User.Id -Type User -IsCloudManaged $IsCloudManaged -Confirm:$false
        }
    }
}

Function Set-MgGroupSourceOfAuthority {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'Group')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Group', ValueFromPipeline)]
        [ValidateScript({ $null -ne $_.Id })]
        [object] $Group,

        [Parameter(Mandatory, ParameterSetName = 'Id')]
        [guid] $Id,

        [Parameter(Mandatory, ParameterSetName = 'DisplayName')]
        [ValidateNotNullOrEmpty()]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [bool] $IsCloudManaged
    )

    process {
        switch ($PSCmdlet.ParameterSetName) {
            'Id' {
                try {
                    $Group = Get-MgGroup -GroupId $Id -ErrorAction Stop
                } catch {
                    Write-Error "Unable to retrieve group with Id '$Id': $($_.Exception.Message)"
                    return
                }
            }
            'DisplayName' {
                try {
                    $escapedDisplayName = $DisplayName.Replace("'", "''")
                    $Group = @(Get-MgGroup -Filter "displayName eq '$escapedDisplayName'" -All -ErrorAction Stop)
                } catch {
                    Write-Error "Unable to retrieve group with DisplayName '$DisplayName': $($_.Exception.Message)"
                    return
                }

                if ($Group.Count -eq 0) {
                    Write-Warning "No group found with DisplayName '$DisplayName'."
                    return
                }
                if ($Group.Count -gt 1) {
                    Write-Warning "Multiple groups found with DisplayName '$DisplayName'; use Id to specify the group."
                    return
                }

                $Group = $Group[0]
            }
        }

        $targetState = if ($IsCloudManaged) { 'cloud managed' } else { 'managed on-premises' }
        if ($PSCmdlet.ShouldProcess("Group '$($Group.Id)'", "Set source of authority to $targetState")) {
            Set-MgSourceOfAuthority -Id $Group.Id -Type Group -IsCloudManaged $IsCloudManaged -Confirm:$false
        }
    }
}

# Preserve Entra-named callers while making the Mg naming the primary interface.
Set-Alias -Name Get-EntraSourceOfAuthority -Value Get-MgSourceOfAuthority
Set-Alias -Name Set-EntraSourceOfAuthority -Value Set-MgSourceOfAuthority
Set-Alias -Name Get-EntraUserSourceOfAuthority -Value Get-MgUserSourceOfAuthority
Set-Alias -Name Set-EntraUserSourceOfAuthority -Value Set-MgUserSourceOfAuthority
Set-Alias -Name Get-EntraGroupSourceOfAuthority -Value Get-MgGroupSourceOfAuthority
Set-Alias -Name Set-EntraGroupSourceOfAuthority -Value Set-MgGroupSourceOfAuthority
Set-Alias -Name Test-EntraSourceOfAuthorityPermission -Value Test-MgSourceOfAuthorityPermissions

$publicFunctions = @(
    'Get-MgSourceOfAuthority'
    'Set-MgSourceOfAuthority'
    'Get-MgUserSourceOfAuthority'
    'Set-MgUserSourceOfAuthority'
    'Get-MgGroupSourceOfAuthority'
    'Set-MgGroupSourceOfAuthority'
    'Test-MgSourceOfAuthorityPermissions'
)

$compatibilityAliases = @(
    'Get-EntraSourceOfAuthority'
    'Set-EntraSourceOfAuthority'
    'Get-EntraUserSourceOfAuthority'
    'Set-EntraUserSourceOfAuthority'
    'Get-EntraGroupSourceOfAuthority'
    'Set-EntraGroupSourceOfAuthority'
    'Test-EntraSourceOfAuthorityPermission'
)

Export-ModuleMember -Function $publicFunctions -Alias $compatibilityAliases
