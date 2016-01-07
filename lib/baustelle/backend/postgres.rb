module Baustelle
  module Backend
    class Postgres
      def initialize(name, options, vpc:)
        @name = name
        @options = options
        @vpc = vpc
      end

      def build(template)
        template.resource sg = "#{prefix}SubnetGroup",
                          Type: 'AWS::RDS::DBSubnetGroup',
                          Properties: {
                            DBSubnetGroupDescription: "#{prefix}SubnetGroup",
                            SubnetIds: @vpc.subnets.map(&:id)
                          }

        template.resource "#{prefix}DBInstance",
                          Type: 'AWS::RDS::DBInstance',
                          Properties: {
                            AllocatedStorage: @options.fetch('storage'),
                            AllowMajorVersionUpgrade: true,
                            AutoMinorVersionUpgrade: true,
                            BackupRetentionPeriod: 7,
                            Engine: 'postgres',
                            DBInstanceClass: @options.fetch('instance_type'),
                            DBName: db_name,
                            DBSubnetGroupName: sg,
                            MasterUsername: @options.fetch('username'),
                            MasterUserPassword: @options.fetch('password'),
                            MultiAZ: @options.fetch('multi_az', true),
                            PubliclyAccessible: false,
                            VPCSecurityGroups: [template.ref('GlobalSecurityGroup')]
                          }
      end

      def output(template)
         host = {'Fn::GetAtt' => ["#{prefix}DBInstance", 'Endpoint.Address']}
         port = {'Fn::GetAtt' => ["#{prefix}DBInstance", 'Endpoint.Port']}

        {
          'url' => {'Fn::Join' => ['', ['postgres://', @options.fetch('username'),
                                        ':', @options.fetch('password'), '@',
                                        host, ':', port, '/', db_name ]] },
          'username' => @options.fetch('username'),
          'password' => @options.fetch('password'),
          'db_name' => db_name,
          'host' => host,
          'port' => port
        }
      end

      private

      def db_name
        @name.underscore
      end

      def prefix
        "Postgres#{@name.camelize}"
      end
    end
  end
end
