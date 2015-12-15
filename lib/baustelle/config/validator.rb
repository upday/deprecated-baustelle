require 'rschema'

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
          'vpc' => Hash,
          'stacks' => Hash,
          'backends' => Hash,
          'applications' => Hash,
          'environments' => Hash
        }}
      end
    end
  end
end
