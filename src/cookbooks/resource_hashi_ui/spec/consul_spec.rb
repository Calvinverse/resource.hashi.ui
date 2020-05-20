# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::consul' do
  context 'configures the consul ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_ui_config_content = <<~JSON
      {
        "ui": true,
        "ui_content_path": "/dashboards/consul"
      }
    JSON
    it 'creates the /etc/consul/conf.d/consul_ui.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/consul_ui.json')
        .with_content(consul_ui_config_content)
    end
  end

  context 'registers the service with consul' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_ui_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:8500/dashboards/consul/ui",
                "id": "consul_ui_status",
                "interval": "15s",
                "method": "GET",
                "name": "Consul UI status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "consul.ui",
            "name": "dashboard",
            "port": 8500,
            "tags": [
              "consul",
              "edgeproxyprefix-/dashboards/consul"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/consul_ui_service.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/consul_ui_service.json')
        .with_content(consul_ui_config_content)
    end

    consul_api_config_content = <<~JSON
      {
        "services": [
          {
            "checks": [
              {
                "http": "http://localhost:8500/dashboards/consul/ui",
                "id": "consul_api_status",
                "interval": "15s",
                "method": "GET",
                "name": "Consul API status",
                "timeout": "5s"
              }
            ],
            "enable_tag_override": false,
            "id": "consul.api",
            "name": "consul",
            "port": 8500,
            "tags": [
              "api",
              "edgeproxyprefix-/v1/ host=dst"
            ]
          }
        ]
      }
    JSON
    it 'creates the /etc/consul/conf.d/consul_api_service.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/consul_api_service.json')
        .with_content(consul_api_config_content)
    end
  end
end
