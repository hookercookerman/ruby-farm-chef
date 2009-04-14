database Mash.new unless attribute?("database")

database[:name] = '' unless database.has_key?(:name)
database[:password] = '' unless database.has_key?(:password)
database[:user] = 'deploy' unless database.has_key?(:user)
database[:host] = 'localhost' unless database.has_key?(:host)

# Set the default database root password
database[:root_password] = '' unless database.has_key?(:root_password)

aws Mash.new unless attribute?("aws")
aws[:access_key] = ''
aws[:secret] = ''
