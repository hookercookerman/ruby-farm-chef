#
# Cookbook Name:: rails
# Recipe:: default
#
# Copyright 2009, Dynamic 50
#
#

include_recipe "mysql::common"

package "git-core"

# Need mysql libraries to compile do_mysql gem
package "libmysqlclient15-dev"

# We need to make sure that the database.yml file is up to date
# This is used like:
# * Capistrano deploy
#   * Deploy everything
#   * chef:run_client
#   * Capistrano copies this file into config/database.yml
template "/tmp/database.yml" do
  owner "deploy"
  group "deploy"
  source "database.yml.erb"
end

# Rake is going to be useful more often than not
bash "install_rake_gem" do
  code "gem install rake"
  not_if "[ `gem search rake | grep rake | wc -l` != 0 ]"
end

# Mysql gem is very difficult to manage if not installed by gem
bash "install_mysql_gem" do
  code "gem install mysql"
  not_if "[ `gem search mysql | grep mysql | wc -l` != 0 ]"
end

# We might need to install some more packages defined in the deploy script
unless node[:extra_apt_packages].nil?
  node[:extra_apt_packages].split(' ').each do |apt_package|
    package apt_package
  end
end

#--------------------------------------------------------------------
# Apache / passenger
#--------------------------------------------------------------------
package "apache2"
package "apache2-threaded-dev"

service "apache2" do
  supports :restart => true
  action :enable
end

# First we need to install and configure the passenger apache module
bash "install_passenger" do
  code <<-EOH
    gem install passenger
    passenger-install-apache2-module -a
    echo "LoadModule passenger_module /usr/lib/ruby/gems/1.8/gems/passenger-2.1.3/ext/apache2/mod_passenger.so" >> /etc/apache2/apache2.conf
    echo "PassengerRoot /usr/lib/ruby/gems/1.8/gems/passenger-2.1.3" >> /etc/apache2/apache2.conf
    echo "PassengerRuby /usr/bin/ruby1.8" >> /etc/apache2/apache2.conf
  EOH
  not_if "[ `cat /etc/apache2/apache2.conf | grep passenger_module | wc -l` != 0 ]"
  notifies :restart, resources("service[apache2]"), :delayed
end

# Set up each rails app on the specified port
unless node[:rails_apps].nil?
  node[:rails_apps].each do |path, port|
    template "/etc/apache2/sites-available/rails_on_#{port}" do
      source "site_available.erb"
      owner "root"
      group "root"
      variables ({
        :path => path,
        :port => port,
      })
      notifies :restart, resources("service[apache2]"), :delayed
    end

    bash "enable_passenger_site" do
      code "ln -s /etc/apache2/sites-available/rails_on_#{port} /etc/apache2/sites-enabled/"
      not_if "[ -e /etc/apache2/sites-enabled/rails_on_#{port} ]"
      notifies :restart, resources("service[apache2]"), :delayed
    end
  end
end
