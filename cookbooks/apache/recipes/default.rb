#
# Cookbook Name:: apache
# Recipe:: default
#
# Copyright 2009, Dynamic 50
#
# All rights reserved - Do Not Redistribute
#
#
package "apache2"

service "apache2" do
  supports :restart => true
  action :enable
end

# Configure apache as a load balancer
unless node[:apache].nil? or node[:apache][:application_servers].nil?
  ports = node[:apache][:application_servers].collect { |server, port| port }
  ports.uniq!
  template "/etc/apache2/sites-available/load_balancer" do
    source "load_balancer.erb"
    owner "root"
    group "root"
      variables ({
        :ports => ports
      })
    notifies :restart, resources("service[apache2]"), :delayed
  end

  bash "enable_apache_load_balancer" do
    code <<-EOH
      ln -s /etc/apache2/sites-available/load_balancer /etc/apache2/sites-enabled/
      a2enmod proxy_balancer
      a2enmod proxy_http
    EOH
    not_if "[ -e /etc/apache2/mods-enabled/proxy_balancer.load ]"
    notifies :restart, resources("service[apache2]"), :delayed
  end

  bash "remove_default_apache_vhost" do
    code "rm /etc/apache2/sites-enabled/000-default"
    not_if "[ ! -e /etc/apache2/sites-enabled/000-default ]"
    notifies :restart, resources("service[apache2]"), :delayed
  end
end
