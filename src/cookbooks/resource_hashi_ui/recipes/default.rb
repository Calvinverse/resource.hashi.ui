# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'resource_hashi_ui::firewall'

include_recipe 'resource_hashi_ui::meta'
include_recipe 'resource_hashi_ui::consul'

include_recipe 'resource_hashi_ui::provisioning'
