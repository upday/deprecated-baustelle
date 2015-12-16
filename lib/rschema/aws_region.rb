module RSchema
  module AwsRegion
    REGIONS = %w(us-east-1 eu-west-1 eu-central-1)
  end

  module DSL
    module Base
      def in_each_region(regions = %w(us-east-1 eu-west-1 eu-central-1), &blk)
        regions.inject({}) { |map, region|
          map.merge(optional(region) => instance_exec(region, &blk))
        }
      end
    end
  end
end
