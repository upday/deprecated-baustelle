module Baustelle
  module Backend
    class Aurora < Base
      def build(template)
        template.resource sg = "#{prefix}SubnetGroup",
                          Type: 'AWS::RDS::DBSubnetGroup',
                          Properties: {
                            DBSubnetGroupDescription: "#{prefix}SubnetGroup",
                            SubnetIds: @vpc.subnets.map(&:id)
                          }

        template.resource "#{prefix}DBCluster",
                          Type: 'AWS::RDS::DBCluster',
                          Properties: {
                            AvailabilityZones: @vpc.availability_zones,
                            BackupRetentionPeriod: 7,
                            DatabaseName: db_name,
                            # Optional DBClusterParameterGroupName: String,
                            DBSubnetGroupName: template.ref(sg),
                            Engine: 'aurora',
                            EngineVersion: '5.6.10a',
                            # Not encrypted KmsKeyId: String,
                            MasterUsername: @options.fetch('username'),
                            MasterUserPassword: @options.fetch('password'),
                            # Use Default Port: Integer,
                            # Use Default PreferredBackupWindow: String,
                            # Use Default PreferredMaintenanceWindow: String,
                            # Create new DB SnapshotIdentifier: String,
                            StorageEncrypted: false,
                            Tags: [
                              {Key: 'application', Value: "#{app_name}"},
                              {Key: 'environment', Value: "#{@env_name}"},
                            ],
                            VpcSecurityGroupIds: [template.ref('GlobalSecurityGroup')]
                          }
        for counter in 1..@options.fetch('instances',2)
          template.resource "#{prefix}DBInstance#{counter}",
                            Type: 'AWS::RDS::DBInstance',
                            Properties: {
                              Engine: 'aurora',
                              DBInstanceClass: @options.fetch('instance_type', 'db.r3.large'),
                              DBClusterIdentifier: template.ref("#{prefix}DBCluster"),
                              MultiAZ: false,
                              Tags: [
                                {Key: 'application', Value: "#{app_name}"},
                                {Key: 'environment', Value: "#{@env_name}"},
                              ],
                            }
        end
      end

      def output(template)
        port = {'Fn::GetAtt' => ["#{prefix}DBCluster", 'Endpoint.Port']}

        {
          'url' => {'Fn::Join' => ['', ['mysql://', @options.fetch('username'),
                                        ':', @options.fetch('password'), '@',
                                        host, ':', port, '/', db_name ]] },
          'jdbc_url' => {'Fn::Join' => ['', ['jdbc:mysql://', host, ':', port, '/', db_name ]] },
          'username' => @options.fetch('username'),
          'password' => @options.fetch('password'),
          'db_name' => db_name,
          'host' => host,
          'port' => port
        }
      end

      private

      def host
        {'Fn::GetAtt' => ["#{prefix}DBCluster", 'Endpoint.Address']}
      end

      def db_name
        @name.underscore
      end

      def prefix
        "Aurora#{@name.camelize}"
      end
      def app_name
        @name.split('_',2)[1]
      end

    end
  end
end
