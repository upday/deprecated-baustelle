require 'rschema'

module RSchema
  module CidrSchema
    extend self

    def schema_walk(value, mapper)
      if matches = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})\/(\d+)$/.match(value.to_s)
        if matches[1..4].all? { |ip_block| (0..255).include?(ip_block.to_i) } &&
           (0..30).include?(matches[5].to_i)
          return value
        end
      end

      RSchema::ErrorDetails.new(value, "is not a valid CIDR")
    end

    def inspect
      'CIDR'
    end
  end

  module DSL
    module Base
      def cidr
        RSchema::CidrSchema
      end
    end
  end
end
