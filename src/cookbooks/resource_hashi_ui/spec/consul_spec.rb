# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::consul' do
  context 'configures the consul ui' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    consul_ui_config_content = <<~JSON
      {
        "ui": true
      }
    JSON
    it 'creates the /etc/consul/conf.d/consul_ui.json' do
      expect(chef_run).to create_file('/etc/consul/conf.d/consul_ui.json')
        .with_content(consul_ui_config_content)
    end
  end
end
