require 'rschema'
require 'rschema/cidr_schema'

module Baustelle
  module Config
    module Validator
      extend self

      def call(config_hash)
        RSchema.validation_error(schema, config_hash)
      end

      private

      def schema
        RSchema.schema {{
          optional('base_amis') => Hash,
          optional('jenkins') => Hash,
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
          'backends' => Hash,
          'applications' => Hash,
          'environments' => Hash
        }}
      end
    end
  end
end
