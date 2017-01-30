module RSchema
  module AwsInstanceType
    INSTANCE_TYPES = {
      ec2: %w(
t2.nano t2.micro t2.small t2.medium t2.large
m4.large m4.xlarge m4.2xlarge m4.4xlarge m4.10xlarge
m3.medium m3.large m3.xlarge m3.2xlarge
c4.large c4.xlarge c4.2xlarge c4.4xlarge c4.8xlarge
c3.large c3.xlarge c3.2xlarge c3.4xlarge c3.8xlarge
r3.large r3.xlarge r3.2xlarge r3.4xlarge r3.8xlarge
r4.large r4.xlarge r4.2xlarge r4.4xlarge r4.8xlarge r4.16xlarge
g2.2xlarge g2.8xlarge
i2.xlarge i2.2xlarge i2.4xlarge i2.8xlarge
d2.xlarge d2.2xlarge d2.4xlarge d2.8xlarge),
      cache: %w(
cache.m1.medium
cache.t2.micro cache.t2.small cache.t2.medium
cache.m3.medium cache.m3.large cache.m3.xlarge cache.m3.2xlarge
cache.m4.large cache.m4.xlarge cache.m4.2xlarge cache.m4.4xlarge cache.m4.10xlarge
cache.r3.large cache.r3.xlarge cache.r3.2xlarge cache.r3.4xlarge cache.r3.8xlarge
),
      rds: %w(
db.m4.large db.m4.xlarge db.m4.2xlarge db.m4.4xlarge db.m4.10xlarge
db.m3.medium db.m3.large db.m3.xlarge db.m3.2xlarge
db.r3.large db.r3.xlarge db.r3.2xlarge db.r3.4xlarge db.r3.8xlarge
db.t2.micro db.t2.small db.t2.medium db.t2.large
)
    }
  end

  module DSL
    module Base
      def instance_type(service = :ec2)
        predicate("is a valid #{service} instance type") { |instance_type|
          RSchema::AwsInstanceType::INSTANCE_TYPES.fetch(service).
            include?(instance_type)
        }
      end
    end
  end
end
