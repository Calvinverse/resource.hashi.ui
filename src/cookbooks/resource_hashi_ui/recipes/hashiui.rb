# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: hashiui
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which vault will be run
hashiui_user = node['hashiui']['service_user']
poise_service_user hashiui_user do
  group node['hashiui']['service_group']
end

#
# INSTALL HASHI-UI
#

hashiui_install_path = node['hashiui']['install_path']

remote_file 'hashiui_release_binary' do
  path hashiui_install_path
  source node['hashiui']['release_url']
  checksum node['hashiui']['checksum']
  owner 'root'
  mode '0755'
  action :create
end

# Set the restart time to be 5 seconds meaning that after a failure to start SystemD will
# try to restart the service 5 seconds later
#
# Also set the StartLimitIntervalSec to 0 so that SystemD doesn't care how many time
# it fails. See: https://unix.stackexchange.com/a/324297
hashiui_service_name = node['hashiui']['service_name']
systemd_service hashiui_service_name do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "#{hashiui_install_path} --consul-enable --consul-read-only --proxy-address /dashboards/consul"
    restart 'always'
    restart_sec 5
    user hashiui_user
  end
  unit do
    after %w[network-online.target]
    description 'Hashi-UI'
    documentation 'https://github.com/jippi/hashi-ui'
    requires %w[network-online.target]
    start_limit_interval_sec 0
  end
end

service hashiui_service_name do
  action :enable
end

#
# ALLOW HASHI-UI THROUGH THE FIREWALL
#

hashiui_port = node['hashiui']['port']
firewall_rule 'http' do
  command :allow
  description 'Allow HTTP traffic'
  dest_port hashiui_port
  direction :in
end

#
# CONNECT TO CONSUL
#

hashiui_proxy_path = node['hashiui']['proxy_path']
file '/etc/consul/conf.d/hashiui.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{hashiui_port}/_status",
              "id": "hashiui_status",
              "interval": "15s",
              "method": "GET",
              "name": "Hashi-UI status",
              "timeout": "5s"
            }
          ],
          "enable_tag_override": false,
          "id": "hashiui.dashboard",
          "name": "dashboard",
          "port": #{hashiui_port},
          "tags": [
            "consul",
            "edgeproxyprefix-#{hashiui_proxy_path} strip=#{hashiui_proxy_path}"
          ]
        }
      ]
    }
  JSON
end
