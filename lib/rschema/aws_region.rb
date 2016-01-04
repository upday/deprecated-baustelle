module RSchema
  module AwsRegion
    REGIONS = %w(us-east-1 us-west-2 us-west-1 eu-west-1 eu-central-1 ap-southeast-1 ap-southeast-2 ap-northeast-1 sa-east-1)
  end

  module DSL
    module Base
      def in_each_region(regions = RSchema::AwsRegion::REGIONS, &blk)
        regions.inject({}) { |map, region|
          map.merge(optional(region) => instance_exec(region, &blk))
        }
      end
    end
  end
end
