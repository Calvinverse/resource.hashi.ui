# frozen_string_literal: true

require 'spec_helper'

describe 'resource_hashi_ui::node' do
  context 'configures node' do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'installs node-js' do
      expect(chef_run).to include_recipe('nodejs::install')
    end

    it 'installs npm' do
      expect(chef_run).to include_recipe('nodejs::npm')
    end

    it 'installs yarn' do
      expect(chef_run).to include_recipe('yarn::install_package')
    end
  end
end
