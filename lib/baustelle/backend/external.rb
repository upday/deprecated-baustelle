module Baustelle
  module Backend
    class External
      def initialize(name, options, vpc:)
        @name = name
        @options = options
        @vpc = vpc
      end

      def build(template)
      end

      def output(template)
        @options.inject({}) do |output, (key, value)|
          output[key.to_s] = value
          output
        end
      end
    end
  end
end
