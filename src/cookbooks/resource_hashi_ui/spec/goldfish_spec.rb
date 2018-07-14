# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::goldfish' do
  before do
    stub_command('getcap $(readlink -f $(which goldfish))|grep cap_ipc_lock+ep').and_return(false)
  end

  context 'configures goldfish' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    it 'installs the goldfish binaries' do
      expect(chef_run).to create_remote_file('goldfish_release_binary').with(
        path: '/usr/local/bin/goldfish',
        source: 'https://github.com/Caiyeon/goldfish/releases/download/v0.9.0/goldfish-linux-amd64'
      )
    end

    it 'installs the goldfish service' do
      expect(chef_run).to create_systemd_service('goldfish').with(
        action: [:create],
        unit_after: %w[network-online.target],
        unit_description: 'Goldfish Vault UI',
        unit_documentation: 'https://github.com/Caiyeon/goldfish',
        unit_requires: %w[network-online.target]
      )
    end

    it 'enables the goldfish service' do
      expect(chef_run).to enable_service('goldfish')
    end

    it 'installs the libcap2-bin package' do
      expect(chef_run).to install_package('libcap2-bin')
    end

    it 'allows goldfish to invoke mlock' do
      expect(chef_run).to run_execute('allow goldfish to lock memory').with(
        command: 'setcap cap_ipc_lock=+ep $(readlink -f $(which goldfish))'
      )
    end
  end

  context 'configures the firewall for goldfish' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the HTTP port' do
      expect(chef_run).to create_firewall_rule('http').with(
        command: :allow,
        dest_port: 8000,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_goldfish_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:8000",
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
            "port": 8000,
            "tags": [
              "vault",
              "edgeproxyprefix-/dashboards/vault strip=/dashboards/vault"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/goldfish.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/goldfish.json')
        .with_content(consul_goldfish_config_content)
    end
  end

  context 'adds the consul-template files for goldfish' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    goldfish_template_content = <<~CONF
      # [Required] listener defines how goldfish will listen to incoming connections
      listener "tcp" {
        # [Required] [Format: "address", "address:port", or ":port"]
        # goldfish's listening address and/or port. Simply ":443" would suffice.
        address = ":8000"

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
    it 'creates goldfish template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/goldfish.ctmpl')
        .with_content(goldfish_template_content)
    end

    consul_template_goldfish_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/goldfish.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/goldfish/config.hcl"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "systemctl restart goldfish"

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
    CONF
    it 'creates goldfish.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/goldfish.hcl')
        .with_content(consul_template_goldfish_content)
    end
  end
end
