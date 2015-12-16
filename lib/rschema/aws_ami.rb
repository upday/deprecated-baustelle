require 'aws-sdk'

module RSchema
  module AwsAmi
    extend self

    def exists?(region, ami_id)
      image(region, ami_id)
    end

    private

    def image(region, ami_id)
      @images ||= {}
      @images[region] ||= {}
      @images[region][ami_id] ||= begin
                                    ec2 = Aws::EC2::Client.new(region: region)
                                    ec2.describe_images(image_ids: [ami_id],
                                                        filters: [{name: 'state',
                                                                   values: ['available']}]).
                                      images.any?
                                  rescue Aws::EC2::Errors::InvalidAMIIDNotFound
                                    false
                                  end
    end
  end

  module DSL
    module Base
      def existing_ami(region)
        predicate("AMI exists and is ready in #{region}") { |ami_id|
          RSchema::AwsAmi.exists?(region, ami_id)
        }
      end
    end
  end
end
