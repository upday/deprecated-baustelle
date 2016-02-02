require "baustelle/version"

# Flush output ASAP
$stdout.sync = true

module Baustelle
  # Your code goes here...
  require 'active_support/core_ext/string'
  require 'baustelle/config'
  require 'baustelle/config/validator'
  require 'baustelle/ami'
  require 'baustelle/stack_template'
  require 'baustelle/stack_template/graph'
  require 'baustelle/cloud_formation'
  require 'baustelle/cloud_formation/remote_template'
  require 'baustelle/cloud_formation/vpc'
  require 'baustelle/cloud_formation/peer_vpc'
  require 'baustelle/cloud_formation/route53'
  require 'baustelle/cloud_formation/application'
  require 'baustelle/cloud_formation/ebenvironment'
  require 'baustelle/cloud_formation/template'
  require 'baustelle/cloud_formation/iam_role'
  require 'baustelle/cloud_formation/bastion_host'
  require 'baustelle/commands/create'
  require 'baustelle/commands/update'
  require 'baustelle/commands/delete'
  require 'baustelle/commands/wait'
  require 'baustelle/commands/jenkins/seed'
  require 'baustelle/commands/jenkins/delete'
  require 'baustelle/commands/read_config'
  require 'baustelle/commands/validate_config'
  require 'baustelle/backend/base'
  require 'baustelle/backend/rabbitmq'
  require 'baustelle/backend/external'
  require 'baustelle/backend/redis'
  require 'baustelle/backend/kinesis'
  require 'baustelle/backend/postgres'
end
