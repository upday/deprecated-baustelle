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
            optional('peers') => Hash
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
