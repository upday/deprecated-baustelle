module Platform
  module CloudFormation
    class Template
      def initialize
        @resources = {}
      end

      def eval(&block)
        instance_exec(&block)
      end

      def resource(name, **params)
        raise "The resource name: #{name} already taken" if @resources[name]
        @resources[name] = params
      end

      def ref(name)
        { 'Ref' => name }
      end

      def join(separator, *elements)
        { 'Fn::Join' => [separator, elements] }
      end

      def camelize(lower_case_and_underscored_word, first_letter_in_uppercase = true)
        if first_letter_in_uppercase
          lower_case_and_underscored_word.to_s.gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
        else
          lower_case_and_underscored_word.first + camelize(lower_case_and_underscored_word)[1..-1]
        end
      end


      def as_json
        {
          AWSTemplateFormatVersion: "2010-09-09",
          Description: "",
          Parameters: {},
          Mappings: {},
          Resources: @resources,
          Outputs: {}
        }
      end
    end
  end
end
