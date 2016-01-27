require 'rschema'
require 'rschema/cidr_schema'
require 'rschema/aws_region'
require 'rschema/aws_ami'
require 'rschema/aws_instance_type'
require 'baustelle/config/validator/application'

module Baustelle
  module Config
    module Validator
      include RSchema::DSL::Base
      extend self

      def call(config_hash)
        RSchema.validation_error(schema(config_hash), config_hash)
      end

      private

      def schema(config_hash)
        root = root_schema(config_hash)

        root.merge('environments' => hash_of(
                     String => optional_tree(root).merge(environment_schema(config_hash))
                   ))
      end

      def environment_schema(config_hash)
        environments = Set.new(config_hash.fetch('environments', {}).keys)
        RSchema.schema {
          {
            optional('eb_application_version_source') => enum(environments + ['git'])
          }
        }
      end

      def optional_tree(root)
        case root
        when Hash
          root.inject({}) { |result, (key, value)|
            result.merge(optional_key(key) => optional_tree(value))
          }
        when RSchema::GenericHashSchema
          RSchema::GenericHashSchema.new(optional_key(root.key_subschema),
                                         optional_tree(root.value_subschema))
        when RSchema::EitherSchema
          RSchema::EitherSchema.new(root.alternatives.map(&method(:optional_tree)))
        when Array
          root.map(&method(:optional_tree))
        else
          root
        end
      end

      def optional_key(key)
        case key
        when RSchema::OptionalHashKey, Class, Struct then key
        else RSchema::OptionalHashKey.new(key)
        end
      end

      def root_schema(config_hash)
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
                'credentials' => {
                  'git' => String,
                  optional('dockerhub') => String
                },
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
            'stacks' => hash_of(
              String => {
                'solution' => String,
                optional('ami') => in_each_region { |region| existing_ami(region) }
              }
            ),
            optional('bastion') => {
              'instance_type' => instance_type,
              'ami' => in_each_region { |region| existing_ami(region) },
              'github_ssh_keys' => [String],
              'dns_zone' => String
            },
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
              optional('Postgres') => hash_of(
                String => {
                  'storage' => Fixnum,
                  'instance_type' => instance_type(:rds),
                  'username' => String,
                  'password' => String,
                  optional('multi_az') => boolean
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
