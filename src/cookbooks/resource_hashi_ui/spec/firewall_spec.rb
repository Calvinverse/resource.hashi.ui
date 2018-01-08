# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::firewall' do
  context 'configures the firewall' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs the default firewall' do
      expect(chef_run).to install_firewall('default')
    end
  end
end
