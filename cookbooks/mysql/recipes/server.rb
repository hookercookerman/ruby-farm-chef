#
# Cookbook Name:: mysql
# Recipe:: default
#
# Copyright 2009, Dynamic 50
#
#
include_recipe "mysql::common"

package "mysql-server"

# This is needed to upload file to s3
package "s3cmd"

service "mysql" do
  supports :start => true, :stop => :true, :restart => true
  action [ :enable, :start ]
end


# It is important to do the mounting etc first, because the password stuff depends
# on the database working

# Make sure the /vol directory is ready
directory "/vol" do
  owner "root"
  group "root"
  mode 0755
  action :create
end

# Format the ebs volume if it isn't already
bash "format_ebs_volume" do
  # Use use fsck to see if a partition is OK, there are a number of problems with this
  # it could be a little slow with large volume, and if we remount a broken one, it will
  # be reformatted. This will have to do for now.
  # -n is needed because otherwise fsck fails because there isn't a shell, 
  code "mkfs.ext3 -F /dev/sdh"
  not_if "[ `mount | grep /vol | wc -l` != 0 ] || fsck -n /dev/sdh"
end

# Make sure vol is mounted
bash "mount_ebs_volume" do
  # We check if the volume is mounted by counting the vol lines from mount
  # I use a double negative here because only_if doesn't seem to work
  code "mount /dev/sdh /vol"
  not_if "[ `mount | grep /vol | wc -l` != 0 ]"
end

template "/etc/mysql/my.cnf" do
  source "my.cnf.erb"
  notifies :restart, resources(:service => "mysql")
end

# Configure the s3 utility
template "/root/.s3cfg" do
  source "s3cfg.erb"
end

# If vol doesn't have the mysql files, we need to set them up
bash "setup_mysql_dir" do
  code <<-EOH
    echo "doing mysql setup" > /tmp/ok
    mkdir -p /vol/log/mysql
    chown -R mysql:mysql /vol/log
    mysql_install_db --user=mysql
  EOH
  not_if do File.exists?("/vol/lib") end
  notifies :restart, resources(:service => "mysql")
end

# Change the mysql default password
bash "set_mysql_root_password" do
  code "mysqladmin -uroot password #{node[:database][:root_password]}"
  # We only run this if logging in with a password fails
  not_if "mysql -uroot -p#{node[:database][:root_password]} -e \"SHOW DATABASES;\""
end

# Set up a user / password for the clients
# There are two statements here, one for localhost and one for all others firewalling 
# should take care of security here, we need access from other ec2 instances to scale
bash "create_client_mysql_user" do
  code <<-EOH
    mysql -uroot -p#{node[:database][:root_password]} -e "GRANT ALL ON *.* TO '#{node[:database][:user]}'@'%' IDENTIFIED BY '#{node[:database][:password]}';"
    mysql -uroot -p#{node[:database][:root_password]} -e "GRANT ALL ON *.* TO '#{node[:database][:user]}'@'localhost' IDENTIFIED BY '#{node[:database][:password]}';"
  EOH
  # Only run this if we can't log in with the username / password
  not_if "mysql -u#{node[:database][:user]} -p#{node[:database][:password]} -e \"SHOW DATABASES;\""
end
