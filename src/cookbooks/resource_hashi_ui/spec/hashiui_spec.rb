# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::hashiui' do
  context 'configures hashi-ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }
    it 'installs the hashi-ui binaries' do
      expect(chef_run).to create_remote_file('hashiui_release_binary').with(
        path: '/usr/local/bin/hashiui',
        source: 'https://github.com/jippi/hashi-ui/releases/download/v1.0.0/hashi-ui-linux-amd64'
      )
    end

    it 'installs the hashi-ui service' do
      expect(chef_run).to create_systemd_service('hashiui').with(
        action: [:create],
        unit_after: %w[network-online.target],
        unit_description: 'Hashi-UI',
        unit_documentation: 'https://github.com/jippi/hashi-ui',
        unit_requires: %w[network-online.target]
      )
    end

    it 'enables the hashi-ui service' do
      expect(chef_run).to enable_service('hashiui')
    end
  end

  context 'configures the firewall for hashi-ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'opens the HTTP port' do
      expect(chef_run).to create_firewall_rule('http').with(
        command: :allow,
        dest_port: 3000,
        direction: :in
      )
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_hashiui_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:3000/_status",
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
            "port": 3000,
            "tags": [
              "consul",
              "edgeproxyprefix-/dashboards/consul strip=/dashboards/consul"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/hashiui.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/hashiui.json')
        .with_content(consul_hashiui_config_content)
    end
  end
end
