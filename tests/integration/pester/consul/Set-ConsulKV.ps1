function Get-IpAddress
{
    $output = & /sbin/ifconfig eth0
    $line = $output |
        Where-Object { $_.Contains('inet addr:') } |
        Select-Object -First 1

    $line = $line.Trim()
    $line = $line.SubString('inet addr:'.Length)
    return $line.SubString(0, $line.IndexOf(' '))
}

function Set-ConsulKV
{
    $consulVersion = '1.0.2'

    Write-Output "Starting consul ..."
    $process = Start-Process -FilePath "/opt/consul/$($consulVersion)/consul" -ArgumentList "agent -config-file /test/pester/consul/server.json" -PassThru -RedirectStandardOutput /test/pester/consul/consuloutput.out -RedirectStandardError /test/pester/consul/consulerror.out

    Write-Output "Going to sleep for 10 seconds ..."
    Start-Sleep -Seconds 10

    Write-Output "Setting consul key-values ..."

    # Load config/services/consul
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/datacenter 'test-integration'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/consul/domain 'integrationtest'

    # Load config/services/metrics
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/opentsdb/host 'write.metrics'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/opentsdb/port '4242'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/statsd/host 'write.statsd'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/metrics/statsd/port '1234'

    # Load config/services/nomad
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/bootstrap '1'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/host 'http.nomad'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/port '4646'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/region 'integrationtest'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/tls/http 'false'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/tls/rpc 'false'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/tls/verify 'false'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/vault/enabled 'false'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/nomad/vault/ts/skip 'true'

    # load config/services/queue
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/host 'active.queue'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/port '5672'

    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/username 'testuser'
    & /opt/consul/$($consulVersion)/consul kv put -http-addr=http://127.0.0.1:8550 config/services/queue/logs/syslog/vhost 'testlogs'

    Write-Output "Joining the local consul ..."

    # connect to the actual local consul instance
    $ipAddress = Get-IpAddress
    Write-Output "Joining: $($ipAddress):8351"

    Start-Process -FilePath "/opt/consul/$($consulVersion)/consul" -ArgumentList "join $($ipAddress):8351"

    Write-Output "Getting members for client"
    & /opt/consul/$($consulVersion)/consul members

    Write-Output "Getting members for server"
    & /opt/consul/$($consulVersion)/consul members -http-addr=http://127.0.0.1:8550

    Write-Output "Giving consul-template 30 seconds to process the data ..."
    Start-Sleep -Seconds 30
}
