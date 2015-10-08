require "platform/version"

module Platform
  # Your code goes here...
  require 'platform/config'
  require 'platform/cloud_formation'
  require 'platform/cloud_formation/vpc'
  require 'platform/cloud_formation/application'
  require 'platform/cloud_formation/ebenvironment'
  require 'platform/cloud_formation/template'
  require 'platform/commands/create'
  require 'platform/commands/update'
  require 'platform/commands/delete'
end
