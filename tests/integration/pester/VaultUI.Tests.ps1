Describe 'The vault-ui application' {
    Context 'is installed' {
        It 'with files in /opt/vaultui' {
            '/opt/vaultui' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/vaultui.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Vault-UI
Requires=network-online.target
After=network-online.target
Documentation=https://github.com/djenriquez/vault-ui

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/local/bin/node ./server.js
User=vaultui
WorkingDirectory=/opt/vaultui
EnvironmentFile=/etc/vaultui_environment
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status vaultui
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'vaultui.service - Vault-UI'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        $response = Invoke-WebRequest -Uri http://localhost:8000 -UseBasicParsing
        $webPage = $response.Content
        It 'responds to HTTP calls' {
            $response.StatusCode | Should Be 200
            $webPage | Should Not Be $null
        }
    }
}
