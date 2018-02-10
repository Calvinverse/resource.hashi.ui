# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: vaultui
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which vaultui will be run
vaultui_user = node['vaultui']['service_user']
vaultui_group = node['vaultui']['service_group']
poise_service_user vaultui_user do
  group vaultui_group
end

#
# INSTALL VAULT-UI
#

vaultui_install_path = node['vaultui']['install_path']
remote_directory vaultui_install_path do
  action :create
  group vaultui_group
  owner 'root'
  mode '0775'
  source 'vault-ui-2.4.0-rc3'
end

yarn_install vaultui_install_path do
  action :run
  user vaultui_user
end

yarn_run 'build-web' do
  dir vaultui_install_path
  user vaultui_user
end

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
vaultui_service_name = node['vaultui']['service_name']
vaultui_env_file = node['vaultui']['environment_file']
systemd_service vaultui_service_name do
  action :create
  after %w[network-online.target]
  description 'Vault-UI'
  documentation 'https://github.com/djenriquez/vault-ui'
  install do
    wanted_by %w[multi-user.target]
  end
  requires %w[network-online.target]
  service do
    environment_file vaultui_env_file
    exec_start '/usr/local/bin/node ./server.js'
    restart 'on-failure'
    working_directory vaultui_install_path
  end
  user vaultui_user
end

# Make sure the hashi-ui service doesn't start automatically. This will be changed
# after we have provisioned the box
service vaultui_service_name do
  action :enable
end

#
# ALLOW HASHI-UI THROUGH THE FIREWALL
#

vaultui_port = node['vaultui']['port']
firewall_rule 'http' do
  command :allow
  description 'Allow HTTP traffic'
  dest_port vaultui_port
  direction :in
end

#
# CONNECT TO CONSUL
#

vaultui_proxy_path = node['vaultui']['proxy_path']
file '/etc/consul/conf.d/vaultui.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{vaultui_port}",
              "id": "vaultui_ping",
              "interval": "15s",
              "method": "GET",
              "name": "Vault-UI ping",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "vaultui.dashboard",
          "name": "dashboard",
          "port": #{vaultui_port},
          "tags": [
            "vault",
            "edgeproxyprefix-#{vaultui_proxy_path} strip=#{vaultui_proxy_path}"
          ]
        }
      ]
    }
  JSON
end

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

# region.hcl
vaultui_template_file = node['vaultui']['consul_template_file']
file "#{consul_template_template_path}/#{vaultui_template_file}" do
  action :create
  content <<~CONF
    VAULT_URL_DEFAULT=http://{{ keyOrDefault "config/services/vault/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}:{{ keyOrDefault "config/services/vault/protocols/http/port" "8200" }}
  CONF
  mode '755'
end

file "#{consul_template_config_path}/vaultui.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{vaultui_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{vaultui_env_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart #{vaultui_service_name}"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0755

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  mode '755'
end
