module Baustelle
  module Commands
    module ValidateConfig
      extend self

      def call(specification_file, region)
        config = Baustelle::Config.read(specification_file)
        case result = Baustelle::Config::Validator.call(config)
        when nil then nil
        when RSchema::ErrorDetails, String
          $stderr.puts result
          exit 1
        else
          raise "Unexpected result #{result.inspect}"
        end
      end
    end
  end
end
