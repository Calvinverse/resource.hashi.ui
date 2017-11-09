Describe 'The hashi-ui application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/hashiui' | Should Exist
        }
    }

    Context 'has been daemonized' {
        $serviceConfigurationPath = '/etc/systemd/system/hashiui.service'
        if (-not (Test-Path $serviceConfigurationPath))
        {
            It 'has a systemd configuration' {
               $false | Should Be $true
            }
        }

        $expectedContent = @'
[Unit]
Description=Hashi-UI
Requires=network-online.target
After=network-online.target
Documentation=https://github.com/jippi/hashi-ui

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/local/bin/hashiui --consul-enable --consul-read-only --nomad-enable --nomad-read-only --proxy-address /dashboards/consul
User=hashiui
EnvironmentFile=/etc/environment
Restart=on-failure

'@
        $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
        $systemctlOutput = & systemctl status hashiui
        It 'with a systemd service' {
            $serviceFileContent | Should Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should Not Be $null
            $systemctlOutput.GetType().FullName | Should Be 'System.Object[]'
            $systemctlOutput.Length | Should BeGreaterThan 3
            $systemctlOutput[0] | Should Match 'hashiui.service - Hashi-UI'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should Match 'Active:\sactive\s\(running\).*'
        }
    }

    Context 'can be contacted' {
        $response = Invoke-WebRequest -Uri http://localhost:3000/_status -UseBasicParsing
        It 'responds to HTTP calls' {
            $response.StatusCode | Should Be 200
        }
    }
}
