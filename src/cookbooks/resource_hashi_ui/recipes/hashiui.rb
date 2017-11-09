# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: hashiui
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which consul will be run
hashiui_user = node['hashiui']['service_user']
poise_service_user hashiui_user do
  group node['hashiui']['service_group']
end

#
# DIRECTORIES
#

hashiui_config_path = node['hashiui']['conf_dir']
directory hashiui_config_path do
  action :create
end

#
# INSTALL FABIO
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

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
hashiui_service_name = node['hashiui']['service_name']
systemd_service hashiui_service_name do
  action :create
  after %w[network-online.target]
  description 'Hashi-UI'
  documentation 'https://github.com/jippi/hashi-ui'
  install do
    wanted_by %w[multi-user.target]
  end
  requires %w[network-online.target]
  service do
    exec_start "#{hashiui_install_path} --consul-enable --consul-read-only --nomad-enable --nomad-read-only --proxy-address /dashboards/consul"
    restart 'on-failure'
    environment_file '/etc/environment'
  end
  user hashiui_user
end

# Make sure the hashi-ui service doesn't start automatically. This will be changed
# after we have provisioned the box
service hashiui_service_name do
  action :disable
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
          "enableTagOverride": false,
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
