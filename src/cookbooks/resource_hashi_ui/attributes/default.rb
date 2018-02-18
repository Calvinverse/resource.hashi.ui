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
hashiui_version = '0.23.0'
default['hashiui']['release_url'] = "https://github.com/jippi/hashi-ui/releases/download/v#{hashiui_version}/hashi-ui-linux-amd64"
default['hashiui']['checksum'] = '64700352FD75DA47502C954B8B2912BED22DCE44823A20E81AE8F2EA52530F5C'

#
# GOLDFISH
#

default['goldfish']['install_path'] = '/usr/local/bin/goldfish'
default['goldfish']['service_name'] = 'goldfish'

default['goldfish']['port'] = 8000
default['goldfish']['proxy_path'] = '/dashboards/vault'

default['goldfish']['service_user'] = 'goldfish'
default['goldfish']['service_group'] = 'goldfish'

default['goldfish']['consul_template_file'] = 'goldfish.ctmpl'
default['goldfish']['config_path'] = '/etc/goldfish'
default['goldfish']['config_file'] = "#{node['goldfish']['config_path']}/config.hcl"

# Installation source
goldfish_version = '0.8.0'
default['goldfish']['release_url'] = "https://github.com/Caiyeon/goldfish/releases/download/v#{goldfish_version}/goldfish-linux-amd64"
default['goldfish']['checksum'] = 'A5BAEF9131CD35F0B42AAA480AB915FAD547C04F7A8806C18EFBFCBC85838ACE'
