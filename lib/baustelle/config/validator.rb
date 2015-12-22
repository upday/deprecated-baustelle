require 'rschema'
require 'rschema/cidr_schema'
require 'rschema/aws_region'
require 'rschema/aws_ami'
require 'rschema/aws_instance_type'
require 'baustelle/config/validator/application'

module Baustelle
  module Config
    module Validator
      REGIONS = %w(us-east-1 eu-west-1 eu-central-1)

      extend self

      def call(config_hash)
        RSchema.validation_error(schema(config_hash), config_hash)
      end

      private

      def schema(config_hash)
        RSchema.schema {
          {
            optional('base_amis') => hash_of(
              String => in_each_region { |region| existing_ami(region) }.
                       merge('user' => String,
                             'system' => enum(%w(ubuntu amazon)),
                             optional('user_data') => String)
            ),
            optional('jenkins') => {
              'connection' => {
                'server_url' => String,
                'username' => String,
                'password' => String
              },
              'options' => {
                optional('credentials_id') => String,
                optional('maven_settings_id') => String
              }
            },
            'vpc' => {
              'cidr' => cidr,
              'subnets' => hash_of(enum(%w(a b c d e)) => cidr),
              optional('peers') => hash_of(
                String => {
                  'vpc_id' => predicate("valid vpc id") { |v| v.is_a?(String) && v =~ /^vpc-.+$/ },
                  'cidr' => cidr
                }
              )
            },
            'stacks' => Hash,
            'backends' => {
              optional('RabbitMQ') => hash_of(
                String => {
                  'ami' => in_each_region { |region| existing_ami(region) },
                  'cluster_size' => Fixnum
                }
              ),
              optional('Redis') => hash_of(
                String => {
                  'cache_node_type' => instance_type(:cache),
                  'cluster_size' => Fixnum,
                  optional('instance_type') => instance_type
                }
              ),
              optional('Kinesis') => hash_of(
                String => {
                  'shard_count' => Fixnum
                }
              ),
              optional('External') => hash_of(String => Hash)
            },
            'applications' => hash_of(
              String => Validator::Application.new(config_hash).schema
            ),
            'environments' => Hash
          }
        }
      end
    end
  end
end
