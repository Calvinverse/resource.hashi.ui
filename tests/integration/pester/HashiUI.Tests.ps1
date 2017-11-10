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

        # It won't be possible to start the service in a test environment because hashi-ui will
        # expect both consul and nomad to be alive. Consul runs on the local machine so that's ok, but
        # nomad isn't ...
    }
}
