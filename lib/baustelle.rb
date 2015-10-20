require "baustelle/version"

module Baustelle
  # Your code goes here...
  require 'baustelle/config'
  require 'baustelle/ami'
  require 'baustelle/stack_template'
  require 'baustelle/cloud_formation'
  require 'baustelle/cloud_formation/vpc'
  require 'baustelle/cloud_formation/application'
  require 'baustelle/cloud_formation/ebenvironment'
  require 'baustelle/cloud_formation/template'
  require 'baustelle/commands/create'
  require 'baustelle/commands/update'
  require 'baustelle/commands/delete'
  require 'baustelle/commands/wait'
  require 'baustelle/commands/read_config'
  require 'baustelle/backend/rabbitmq'
end
