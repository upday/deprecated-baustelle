module Baustelle
  module CloudFormation
    class Template
      def initialize
        @resources = {}
        @mappings = {}
        @outputs = {}
        @childs = {}
      end

      def mapping(name, map)
        @mappings[name] = map
      end

      def childs
        @childs
      end

      def add_to_region_mapping(name, region, key, value)
        map = (@mappings[name.camelize] ||= {})
        map[region] ||= {}
        map[region][key.camelize] = value
      end

      def resource(name, **params)
        raise "The resource name: #{name} is already taken" if @resources[name]
        @resources[name] = params
      end

      def output(name, value, description:)
        raise "The output name: #{name} is already taken" if @resources[name]
        @outputs[name] = {
          Description: description,
          Value: value
        }
      end

      def ref(name)
        { 'Ref' => name }
      end

      def join(separator, *elements)
        { 'Fn::Join' => [separator, elements] }
      end

      def resources
        @resources
      end

      def as_json
        {
          AWSTemplateFormatVersion: "2010-09-09",
          Description: "",
          Parameters: {},
          Mappings: @mappings,
          Resources: @resources,
          Outputs: @outputs
        }
      end

      def to_json
        as_json.to_json
      end

      def find_in_regional_mapping(name,  key)
        {'Fn::FindInMap' => [name.camelize, ref('AWS::Region'), key.camelize]}
      end
    end
  end
end
