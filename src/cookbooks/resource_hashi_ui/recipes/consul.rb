# frozen_string_literal: true

#
# Cookbook Name:: resource_hashi_ui
# Recipe:: consul
#
# Copyright 2017, P. van der Velde
#

ui_proxy_path = node['consul']['proxy_path']
file '/etc/consul/conf.d/consul_ui.json' do # ~FC005
  action :create
  content <<~JSON
    {
      "ui": true,
      "ui_content_path": "#{ui_proxy_path}"
    }
  JSON
end

# Overwrite the consul service configuration because we need another command line parameter
# Once the issue with the 'ui_content_path' is fixed we can remove this
# (see: https://github.com/hashicorp/consul/issues/6346)
ui_proxy_path = node['consul']['proxy_path']
systemd_service 'consul' do
  action :create
  install do
    wanted_by %w[multi-user.target]
  end
  service do
    environment '"GOMAXPROCS=2" "PATH=/usr/local/bin:/usr/bin:/bin"'
    exec_reload '/bin/kill -HUP $MAINPID'
    exec_start "/opt/consul/1.6.2/consul agent -config-file=/etc/consul/consul.json -config-dir=/etc/consul/conf.d -ui-content-path #{ui_proxy_path}"
    kill_signal 'TERM'
    restart 'always'
    restart_sec 5
    user 'consul'
    working_directory '/var/lib/consul'
  end
  unit do
    after %w[network.target]
    description 'consul'
    start_limit_interval_sec 0
    wants %w[network.target]
  end
end

#
# UI SERVICE
#

consul_http_port = node['consul']['ports']['http']
file '/etc/consul/conf.d/consul_ui_service.json' do
  action :create
  content <<~JSON
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
          "port": #{consul_http_port},
          "tags": [
            "consul",
            "edgeproxyprefix-#{ui_proxy_path}"
          ]
        }
      ]
    }
  JSON
end

#
# API SERVICE
#

# The consul UI needs access to the V1 REST endpoint in Consul in order to display data
# but it doesn't handle proxies very well (i.e. not at all), so we put the /v1 endpoint
# on the proxy too, so that the UI can get to it.
# see: https://github.com/hashicorp/consul/issues/1382
#
# The drawback of doing that is that anything that has a /v1 endpoint will be redirected
# to consul, with potentially entertaining results (e.g. if you want to proxy the Vault UI).
consul_http_port = node['consul']['ports']['http']
file '/etc/consul/conf.d/consul_api_service.json' do
  action :create
  content <<~JSON
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
          "port": #{consul_http_port},
          "tags": [
            "api",
            "edgeproxyprefix-/v1/ host=dst"
          ]
        }
      ]
    }
  JSON
end
