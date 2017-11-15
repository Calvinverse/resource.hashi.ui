# frozen_string_literal: true

#
# CONSUL
#

default['consul']['version'] = '0.9.2'
default['consul']['config']['domain'] = 'consulverse'

# This is not a consul server node
default['consul']['config']['server'] = false

# For the time being don't verify incoming and outgoing TLS signatures
default['consul']['config']['verify_incoming'] = false
default['consul']['config']['verify_outgoing'] = false

# Bind the client address to the local host. The advertise and bind addresses
# will be set in a separate configuration file
default['consul']['config']['client_addr'] = '127.0.0.1'

# Do not allow consul to use the host information for the node id
default['consul']['config']['disable_host_node_id'] = true

# Disable remote exec
default['consul']['config']['disable_remote_exec'] = true

# Disable the update check
default['consul']['config']['disable_update_check'] = true

# Set the DNS configuration
default['consul']['config']['dns_config'] = {
  allow_stale: true,
  max_stale: '87600h',
  node_ttl: '10s',
  service_ttl: {
    '*': '10s'
  }
}

# Always leave the cluster if we are terminated
default['consul']['config']['leave_on_terminate'] = true

# Send all logs to syslog
default['consul']['config']['log_level'] = 'INFO'
default['consul']['config']['enable_syslog'] = true

default['consul']['config']['owner'] = 'root'

#
# FIREWALL
#

# Allow communication on the loopback address (127.0.0.1 and ::1)
default['firewall']['allow_loopback'] = true

# Do not allow MOSH connections
default['firewall']['allow_mosh'] = false

# Do not allow WinRM (which wouldn't work on Linux anyway, but close the ports just to be sure)
default['firewall']['allow_winrm'] = false

# No communication via IPv6 at all
default['firewall']['ipv6_enabled'] = false

#
# HASHI-UI
#

default['hashiui']['install_path'] = '/usr/local/bin/hashiui'
default['hashiui']['service_name'] = 'hashiui'

default['hashiui']['port'] = 3000
default['hashiui']['proxy_path'] = '/dashboards/consul'

default['hashiui']['service_user'] = 'hashiui'
default['hashiui']['service_group'] = 'hashiui'

# Installation source
hashiui_version = '0.22.0'
default['hashiui']['release_url'] = "https://github.com/jippi/hashi-ui/releases/download/v#{hashiui_version}/hashi-ui-linux-amd64"
default['hashiui']['checksum'] = 'F8489334E6FD187E75E20F5241D615EAE07EA809160310C32B96448AA391AB85'

#
# PROVISIONING
#

#
# UNBOUND
#

default['unbound']['service_user'] = 'unbound'
default['unbound']['service_group'] = 'unbound'

default['paths']['unbound_config'] = '/etc/unbound.d'

default['file_name']['unbound_config_file'] = 'unbound.conf'
