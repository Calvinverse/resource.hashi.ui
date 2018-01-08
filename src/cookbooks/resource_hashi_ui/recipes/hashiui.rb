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

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
hashiui_service_name = node['hashiui']['service_name']
hashiui_env_file = node['hashiui']['environment_file']
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
    environment_file hashiui_env_file
  end
  user hashiui_user
end

# Make sure the hashi-ui service doesn't start automatically. This will be changed
# after we have provisioned the box
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

#
# CONSUL-TEMPLATE FILES
#

consul_template_config_path = node['consul_template']['config_path']
consul_template_template_path = node['consul_template']['template_path']

# region.hcl
hashiui_template_file = node['hashiui']['consul_template_file']
file "#{consul_template_template_path}/#{hashiui_template_file}" do
  action :create
  content <<~CONF
    NOMAD_ADDR=http://{{ keyOrDefault "config/services/nomad/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}:{{ keyOrDefault "config/services/nomad/protocols/http/port" "4646" }}
  CONF
  mode '755'
end

file "#{consul_template_config_path}/hashiui.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{hashiui_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{hashiui_env_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart #{hashiui_service_name}"

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
