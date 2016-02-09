require "spec_helper"

describe Baustelle::CloudFormation::IAMRole do
  let(:default_iam_role){
    Baustelle::CloudFormation::IAMRole.new('', {'describe_tags' => {
      'action' => 'ec2:DescribeTags'
    },
                                     'describe_instances' => {
                                       'action' => 'ec2:DescribeInstances'
                                     },
                                     'elastic_beanstalk_bucket_access' => {
                                       'action' => ['s3:Get*', 's3:List*', 's3:PutObject'],
                                       'resource' => [
                                         "arn:aws:s3:::elasticbeanstalk-*-*",
                                         "arn:aws:s3:::elasticbeanstalk-*-*/*",
                                         "arn:aws:s3:::elasticbeanstalk-*-*-*",
                                         "arn:aws:s3:::elasticbeanstalk-*-*-*/*"
                                       ]
                                     }
    })
  }
  describe "#inherit" do
    subject {
      default_iam_role.inherit("testname",iam_role_config)
    }
    context "IAM role defined" do
      let(:iam_role_config){
        {
          "iam_instance_profile":{
            "testname":{
              "action":[
                "testname:testaction"
              ],
              "resource":"testresource"
            }
          }
        }
      }

      it 'should create a new IAM role' do
        expect(subject.instance_profile_name).to match("IAMInstanceProfileTestname")
      end
    end
    context "IAM role undefined" do
      let(:iam_role_config){
        {}
      }
      it 'should return base IAM role' do
        expect(subject.instance_profile_name).to match("IAMInstanceProfile")
      end
    end
  end
end
