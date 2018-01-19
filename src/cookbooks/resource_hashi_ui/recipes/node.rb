# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: node
#
# Copyright 2017, P. van der Velde
#

include_recipe 'nodejs::install'
include_recipe 'nodejs::npm'
include_recipe 'yarn::install_package'
