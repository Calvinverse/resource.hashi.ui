# frozen_string_literal: true

#
#


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
