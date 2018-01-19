# frozen_string_literal: true

#
# CONSULTEMPLATE
#

default['consul_template']['config_path'] = '/etc/consul-template.d/conf'
default['consul_template']['template_path'] = '/etc/consul-template.d/templates'

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

default['hashiui']['consul_template_file'] = 'hashiui.ctmpl'
default['hashiui']['environment_file'] = '/etc/hashiui_environment'

# Installation source
hashiui_version = '0.22.0'
default['hashiui']['release_url'] = "https://github.com/jippi/hashi-ui/releases/download/v#{hashiui_version}/hashi-ui-linux-amd64"
default['hashiui']['checksum'] = 'F8489334E6FD187E75E20F5241D615EAE07EA809160310C32B96448AA391AB85'

#
# NODE-JS
#

default['nodejs']['install_method'] = 'binary'
default['nodejs']['version'] = '8.9.4'
default['nodejs']['binary']['checksum'] = '68B94AAC38CD5D87AB79C5B38306E34A20575F31A3EA788D117C20FFFCCA3370'

#
# VAULT-UI
#

default['vaultui']['install_path'] = '/opt/vaultui'
default['vaultui']['service_name'] = 'vaultui'

default['vaultui']['port'] = 8000
default['vaultui']['proxy_path'] = '/dashboards/vault'

default['vaultui']['service_user'] = 'vaultui'
default['vaultui']['service_group'] = 'vaultui'

default['vaultui']['consul_template_file'] = 'vaultui.ctmpl'
default['vaultui']['environment_file'] = '/etc/vaultui_environment'

# Installation source
vaultui_version = '0.22.0'
default['vaultui']['release_url'] = "https://github.com/jippi/hashi-ui/releases/download/v#{vaultui_version}/hashi-ui-linux-amd64"
default['vaultui']['checksum'] = 'F8489334E6FD187E75E20F5241D615EAE07EA809160310C32B96448AA391AB85'
