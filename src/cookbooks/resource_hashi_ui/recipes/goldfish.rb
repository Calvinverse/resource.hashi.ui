# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: goldfish
#
# Copyright 2017, P. van der Velde
#

# Configure the service user under which vault will be run
goldfish_user = node['goldfish']['service_user']
poise_service_user goldfish_user do
  group node['goldfish']['service_group']
end

#
# INSTALL HASHI-UI
#

goldfish_install_path = node['goldfish']['install_path']

remote_file 'goldfish_release_binary' do
  path goldfish_install_path
  source node['goldfish']['release_url']
  checksum node['goldfish']['checksum']
  owner 'root'
  mode '0755'
  action :create
end

goldfish_config_path = node['goldfish']['config_path']
directory goldfish_config_path do
  action :create
  owner 'root'
  mode '0755'
end

# Create the systemd service for scollector. Set it to depend on the network being up
# so that it won't start unless the network stack is initialized and has an
# IP address
goldfish_service_name = node['goldfish']['service_name']
goldfish_config_file = node['goldfish']['config_file']
systemd_service goldfish_service_name do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    exec_start "#{goldfish_install_path} -config=#{goldfish_config_file}"
    restart 'on-failure'
    user goldfish_user
  end
  unit do
    after %w[network-online.target]
    description 'Goldfish Vault UI'
    documentation 'https://github.com/Caiyeon/goldfish'
    requires %w[network-online.target]
  end
end

service goldfish_service_name do
  action :enable
end

#
# ALLOW GOLDFISH TO LOCK MEMORY WITH MLOCK
#
# See: https://www.vaultproject.io/guides/operations/production.html

package 'libcap2-bin' do
  action :install
end

execute 'allow goldfish to lock memory' do
  action :run
  command 'setcap cap_ipc_lock=+ep $(readlink -f $(which goldfish))'
  not_if 'getcap $(readlink -f $(which goldfish))|grep cap_ipc_lock+ep'
end

#
# ALLOW HASHI-UI THROUGH THE FIREWALL
#

goldfish_port = node['goldfish']['port']
firewall_rule 'http' do
  command :allow
  description 'Allow HTTP traffic'
  dest_port goldfish_port
  direction :in
end

#
# CONNECT TO CONSUL
#

goldfish_proxy_path = node['goldfish']['proxy_path']
file '/etc/consul/conf.d/goldfish.json' do
  action :create
  content <<~JSON
    {
      "services": [
        {
          "checks": [
            {
              "http": "http://localhost:#{goldfish_port}",
              "id": "goldfish_status",
              "interval": "15s",
              "method": "GET",
              "name": "Goldfish status",
              "timeout": "5s"
            }
          ],
          "enableTagOverride": false,
          "id": "goldfish.dashboard",
          "name": "dashboard",
          "port": #{goldfish_port},
          "tags": [
            "vault",
            "edgeproxyprefix-#{goldfish_proxy_path} strip=#{goldfish_proxy_path}"
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
goldfish_template_file = node['goldfish']['consul_template_file']
file "#{consul_template_template_path}/#{goldfish_template_file}" do
  action :create
  content <<~CONF
    # [Required] listener defines how goldfish will listen to incoming connections
    listener "tcp" {
      # [Required] [Format: "address", "address:port", or ":port"]
      # goldfish's listening address and/or port. Simply ":443" would suffice.
      address = ":#{goldfish_port}"

      # [Optional] [Default: 0] [Allowed values: 0, 1]
      # set to 1 to disable tls & https
      tls_disable = 1

      # [Optional] [Default: 0] [Allowed values: 0, 1]
      # set to 1 to redirect port 80 to 443 (hard-coded port numbers)
      tls_autoredirect = 0
    }

    # [Required] vault defines how goldfish should bootstrap to vault
    vault {
      # [Required] [Format: "protocol://address:port"]
      # This is vault's address. Vault must be up before goldfish is deployed!
      address = "http://{{ keyOrDefault "config/services/secrets/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}:{{ keyOrDefault "config/services/secrets/protocols/http/port" "8200" }}"

      # [Optional] [Default: 0] [Allowed values: 0, 1]
      # Set this to 1 to skip verifying the certificate of vault (e.g. self-signed certs)
      tls_skip_verify = 1

      # [Required] [Default: "secret/goldfish"]
      # This should be a generic secret endpoint where runtime settings are stored
      # See wiki for what key values are required in this
      runtime_config = "secret/goldfish"

      # [Optional] [Default: "auth/approle/login"]
      # You can omit this, unless you mounted approle somewhere weird
      approle_login = "auth/approle/login"

      # [Optional] [Default: "goldfish"]
      # You can omit this if you already customized the approle ID to be 'goldfish'
      approle_id = "goldfish"
    }

    # [Optional] [Default: 0] [Allowed values: 0, 1]
    # Set to 1 to disable mlock. Implementation is similar to vault - see vault docs for details
    # This option will be ignored on unsupported platforms (e.g Windows)
    disable_mlock = 0
  CONF
  mode '755'
end

file "#{consul_template_config_path}/goldfish.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{goldfish_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{goldfish_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart #{goldfish_service_name}"

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
