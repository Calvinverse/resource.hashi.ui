# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: consul
#
# Copyright 2017, P. van der Velde
#

file '/etc/consul/conf.d/consul_ui.json' do
  action :create
  content <<~JSON
    {
      "ui": true
    }
  JSON
end
