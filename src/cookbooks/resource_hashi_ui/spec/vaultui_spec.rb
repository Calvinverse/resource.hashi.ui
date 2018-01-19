# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::vaultui' do
  context 'configures vault-ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    it 'installs the vault-ui source' do
      expect(chef_run).to create_remote_directory('/opt/vaultui').with(
        source: 'vault-ui-2.4.0-rc3'
      )
    end

    it 'restores all the NPM packages with yarn' do
      expect(chef_run).to run_yarn_install('/opt/vaultui')
    end

    it 'runs the yarn build steps' do
      expect(chef_run).to run_yarn_run('build-web')
    end

    it 'installs the hashi-ui service' do
      expect(chef_run).to create_systemd_service('vaultui').with(
        action: [:create],
        after: %w[network-online.target],
        description: 'Vault-UI',
        documentation: 'https://github.com/djenriquez/vault-ui',
        requires: %w[network-online.target]
      )
    end

    it 'enables the hashi-ui service' do
      expect(chef_run).to enable_service('vaultui')
    end
  end

  context 'configures the firewall for vault-ui' do
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

    consul_vaultui_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:8000",
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
            "port": 8000,
            "tags": [
              "vault",
              "edgeproxyprefix-/dashboards/vault strip=/dashboards/vault"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/vaultui.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/vaultui.json')
        .with_content(consul_vaultui_config_content)
    end
  end

  context 'adds the consul-template files for vault-ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    vaultui_template_content = <<~CONF
      VAULT_URL_DEFAULT=http://{{ keyOrDefault "config/services/vault/protocols/http/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}:{{ keyOrDefault "config/services/vault/protocols/http/port" "8200" }}
    CONF
    it 'creates vaultui template file in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/templates/vaultui.ctmpl')
        .with_content(vaultui_template_content)
    end

    consul_template_vaultui_content = <<~CONF
      # This block defines the configuration for a template. Unlike other blocks,
      # this block may be specified multiple times to configure multiple templates.
      # It is also possible to configure templates via the CLI directly.
      template {
        # This is the source file on disk to use as the input template. This is often
        # called the "Consul Template template". This option is required if not using
        # the `contents` option.
        source = "/etc/consul-template.d/templates/vaultui.ctmpl"

        # This is the destination path on disk where the source template will render.
        # If the parent directories do not exist, Consul Template will attempt to
        # create them, unless create_dest_dirs is false.
        destination = "/etc/vaultui_environment"

        # This options tells Consul Template to create the parent directories of the
        # destination path if they do not exist. The default value is true.
        create_dest_dirs = false

        # This is the optional command to run when the template is rendered. The
        # command will only run if the resulting template changes. The command must
        # return within 30s (configurable), and it must have a successful exit code.
        # Consul Template is not a replacement for a process monitor or init system.
        command = "systemctl restart vaultui"

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
    it 'creates vaultui.hcl in the consul-template template directory' do
      expect(chef_run).to create_file('/etc/consul-template.d/conf/vaultui.hcl')
        .with_content(consul_template_vaultui_content)
    end
  end
end
