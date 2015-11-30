require "baustelle/version"

module Baustelle
  # Your code goes here...
  require 'active_support/core_ext/string'
  require 'baustelle/config'
  require 'baustelle/ami'
  require 'baustelle/stack_template'
  require 'baustelle/cloud_formation'
  require 'baustelle/cloud_formation/remote_template'
  require 'baustelle/cloud_formation/vpc'
  require 'baustelle/cloud_formation/peer_vpc'
  require 'baustelle/cloud_formation/application'
  require 'baustelle/cloud_formation/ebenvironment'
  require 'baustelle/cloud_formation/template'
  require 'baustelle/commands/create'
  require 'baustelle/commands/update'
  require 'baustelle/commands/delete'
  require 'baustelle/commands/wait'
  require 'baustelle/commands/jenkins/seed'
  require 'baustelle/commands/jenkins/delete'
  require 'baustelle/commands/read_config'
  require 'baustelle/backend/rabbitmq'
  require 'baustelle/backend/external'
  require 'baustelle/backend/redis'
  require 'baustelle/backend/kinesis'
end
