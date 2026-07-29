BeforeAll {
    $script:ModuleRoot = Split-Path $PSScriptRoot -Parent
    $script:ManifestPath = Join-Path $ModuleRoot 'MgSourceOfAuthority.psd1'
    $script:ModulePath = Join-Path $ModuleRoot 'MgSourceOfAuthority.psm1'
}

Describe 'Module structure' {
    It 'has a valid module manifest' {
        { Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop } |
            Should -Not -Throw
    }

    It 'has valid PowerShell syntax' {
        $tokens = $null
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $ModulePath,
            [ref] $tokens,
            [ref] $errors
        ) | Out-Null

        $errors | Should -BeNullOrEmpty
    }

    It 'explicitly declares its public functions' {
        $manifest = Import-PowerShellDataFile -Path $ManifestPath

        $manifest.FunctionsToExport | Should -Be @(
            'Get-MgSourceOfAuthority'
            'Set-MgSourceOfAuthority'
            'Get-MgUserSourceOfAuthority'
            'Set-MgUserSourceOfAuthority'
            'Get-MgGroupSourceOfAuthority'
            'Set-MgGroupSourceOfAuthority'
            'Test-MgSourceOfAuthorityPermissions'
        )
    }
}

Describe 'Exported commands' {
    BeforeAll {
        $script:Module = Import-Module $ModulePath -Force -PassThru
    }

    AfterAll {
        Remove-Module $Module.Name -Force -ErrorAction SilentlyContinue
    }

    It 'exports the expected Mg functions' {
        $Module.ExportedFunctions.Keys | Sort-Object | Should -Be @(
            'Get-MgGroupSourceOfAuthority'
            'Get-MgSourceOfAuthority'
            'Get-MgUserSourceOfAuthority'
            'Set-MgGroupSourceOfAuthority'
            'Set-MgSourceOfAuthority'
            'Set-MgUserSourceOfAuthority'
            'Test-MgSourceOfAuthorityPermissions'
        )
    }

    It 'exports Entra compatibility aliases that resolve to Mg functions' {
        foreach ($alias in $Module.ExportedAliases.Values) {
            $alias.ResolvedCommandName | Should -Match '-Mg'
        }
    }
}

Describe 'Source-of-authority behavior' {
    BeforeAll {
        Import-Module $ModulePath -Force
    }

    AfterAll {
        Remove-Module MgSourceOfAuthority -Force -ErrorAction SilentlyContinue
    }

    InModuleScope MgSourceOfAuthority {
        BeforeEach {
            Mock Get-MgContext {
                [pscustomobject]@{
                    Scopes = @(
                        'User-OnPremisesSyncBehavior.ReadWrite.All'
                        'Group-OnPremisesSyncBehavior.ReadWrite.All'
                    )
                }
            }
        }

        It 'detects a granted resource permission' {
            Test-MgSourceOfAuthorityPermissions -Type User |
                Should -BeTrue
        }

        It 'normalizes a direct Graph response' {
            Mock Invoke-MgGraphRequest {
                @{
                    isCloudManaged = $true
                }
            }

            $result = Get-MgSourceOfAuthority `
                -Id '00000000-0000-0000-0000-000000000001' `
                -Type User

            $result.Id | Should -Be '00000000-0000-0000-0000-000000000001'
            $result.Type | Should -Be 'User'
            $result.IsCloudManaged | Should -BeTrue
            Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'GET' -and
                $Uri -eq '/v1.0/users/00000000-0000-0000-0000-000000000001/onPremisesSyncBehavior'
            }
        }

        It 'does not send a PATCH request with WhatIf' {
            Mock Invoke-MgGraphRequest {
                if ($Method -eq 'GET') {
                    return @{
                        isCloudManaged = $false
                    }
                }
            }

            Set-MgSourceOfAuthority `
                -Id '00000000-0000-0000-0000-000000000001' `
                -Type User `
                -IsCloudManaged $true `
                -WhatIf

            Should -Invoke Invoke-MgGraphRequest -Times 1 -ParameterFilter {
                $Method -eq 'GET'
            }
            Should -Invoke Invoke-MgGraphRequest -Times 0 -ParameterFilter {
                $Method -eq 'PATCH'
            }
        }

        It 'uses the v1.0 endpoint when changing the state' {
            Mock Invoke-MgGraphRequest {
                if ($Method -eq 'GET') {
                    return @{
                        isCloudManaged = $false
                    }
                }
            }

            Set-MgSourceOfAuthority `
                -Id '00000000-0000-0000-0000-000000000001' `
                -Type User `
                -IsCloudManaged $true `
                -Confirm:$false

            Should -Invoke Invoke-MgGraphRequest -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and
                $Uri -eq '/v1.0/users/00000000-0000-0000-0000-000000000001/onPremisesSyncBehavior'
            }
        }
    }
}
