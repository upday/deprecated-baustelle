require "spec_helper"
require "baustelle/script/cli"

describe Baustelle::Script::CLI do

  describe "#systemtest_env" do
    let(:eb){
      mock_eb_client(
        describe_environments: environment(cname: "foo-cname"),
        describe_configuration_settings: option_settings(opts))
    }
    before(:each)do
      allow(Aws::ElasticBeanstalk::Client).to receive(:new).and_return(eb)
    end
    context "using HTTP" do

      let(:opts){
        [option("some-ignored-namespace", "fooz", "baz"), envvar("FOO_VAR", "bar"), envvar("FOO_VAR2", "bar2")]
      }

      it "displays the environment variables and the cname in APPLICATION_URL" do
        expect { subject.systemtests_env("foo-app", "foo-env") }.to output(<<-ENV
FOO_VAR=bar
FOO_VAR2=bar2
APPLICATION_URL=http://foo-cname
HOST=http://foo-cname
ENV
        ).to_stdout

        expect(eb).to have_received(:describe_configuration_settings)
                  .with(application_name: "foo-app", environment_name: "foo-env")
        expect(eb).to have_received(:describe_environments)
                  .with(environment_names: ["foo-env"])
    end

    it "displays the environment variables and the alternate dns in APPLICATION_URL" do
      subject.options = { "alternate-dns" => "custom-foo-domain" }
      expect { subject.systemtests_env("foo-app", "foo-env") }.to output(<<-ENV
FOO_VAR=bar
FOO_VAR2=bar2
APPLICATION_URL=http://custom-foo-domain
HOST=http://custom-foo-domain
ENV
      ).to_stdout

      expect(eb).to have_received(:describe_configuration_settings)
                .with(application_name: "foo-app", environment_name: "foo-env")
      expect(eb).not_to have_received(:describe_environments)
    end
  end


    context "using HTTPS"do
      let(:opts){
        [option("aws:elb:policies:SSL", "LoadBalancerPorts", "443"), envvar("FOO_VAR", "bar"), envvar("FOO_VAR2", "bar2")]
      }

      it "uses https://<cname> as APPLICATION_URL" do
        expect { subject.systemtests_env("foo-app", "foo-env") }.to output(<<-ENV
FOO_VAR=bar
FOO_VAR2=bar2
APPLICATION_URL=https://foo-cname
HOST=https://foo-cname
ENV
        ).to_stdout
      end


      it "uses https://<alternate-dns> as APPLICATION_URL" do
        subject.options = { "alternate-dns" => "custom-foo-domain" }
        expect { subject.systemtests_env("foo-app", "foo-env") }.to output(<<-ENV
FOO_VAR=bar
FOO_VAR2=bar2
APPLICATION_URL=https://custom-foo-domain
HOST=https://custom-foo-domain
ENV
        ).to_stdout
      end
      end

      context "HTTP/HTTPS"do
        let(:opts){
          [envvar("JAVA_HOME_foo", "bar2"), envvar("FOO_VAR", "bar"), envvar("M2_HOME", "bar2")]
        }

      it "removes environment variables starting with M2 and JAVA_HOME" do
        expect { subject.systemtests_env("foo-app", "foo-env") }.to output(<<-ENV
FOO_VAR=bar
APPLICATION_URL=http://foo-cname
HOST=http://foo-cname
ENV
        ).to_stdout
      end
    end
  end


  private

  def mock_eb_client(methods = default_eb_client_methods)
    eb = instance_double(Aws::ElasticBeanstalk::Client, methods)
    allow(Aws::ElasticBeanstalk::Client).to receive(:new).and_return(eb)
    eb
  end

  def environment(methods)
    environment = instance_double("environment", methods)
    instance_double("describe_environments_result", environments: [environment])
  end

  def option_settings(option_settings)
    settings = instance_double("configuration_settings", option_settings: option_settings)
    instance_double("describe_configuration_settings_result", configuration_settings: [settings])
  end

  def envvar(key, value)
    option("aws:elasticbeanstalk:application:environment", key, value)
  end

  def option(namespace, key, value)
    instance_double("option", namespace: namespace, option_name: key, value: value)
  end

  def default_eb_client_methods()
    {
      describe_environments: environment(cname: "foo-cname"),
      describe_configuration_settings: option_settings([])
    }
  end
end
