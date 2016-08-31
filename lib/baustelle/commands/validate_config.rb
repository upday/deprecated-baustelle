module Baustelle
  module Commands
    module ValidateConfig
      extend self

      def call(specification_file, region)
        config = Baustelle::Config.read(specification_file)
        template = Baustelle::StackTemplate.new(config).build('ValidationTemplate', region)
        if template.resources.length > 199
          $stderr.puts "Number of resources exceeds the maximum of 199. Number of reouces in the template: #{template.resources.length}"
          exit 1
        end
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
