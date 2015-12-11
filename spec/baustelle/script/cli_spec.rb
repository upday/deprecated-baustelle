require "spec_helper"
require "baustelle/cli"

describe 'Baustelle::Script::CLI' do

  describe "#systemtest_env" do
    let(:eb) {
      instance_double(Aws::ElasticBeanstalk::Client,
        describe_environments: environment(cname: cname),
        describe_configuration_settings: option_settings(opts))
    }
    let(:cname) {
      "foo-cname"
    }
    let(:specification) {
      {
        'environments' => {'staging' => {}},
        'applications' => {'user_service' => app_config},
      }
    }
    let(:app_config) {
      {}
    }
    let(:opts){
      [option("some-ignored-namespace", "fooz", "baz"), envvar("FOO_VAR", "bar"), envvar("FOO_VAR2", "bar2")]
    }

    before(:each) do
      expect(Aws::ElasticBeanstalk::Client).to receive(:new).and_return(eb)
      expect(Baustelle::Config).to receive(:read).with('baustelle.yml').and_return(specification)
    end



    it "displays the environment variables and the cname in APPLICATION_URL" do
      expect { run(["script", "systemtest-env", "user_service", "staging"]) }.to output(generate_env("http", cname)).to_stdout

      expect(eb).to have_received(:describe_configuration_settings)
                .with(application_name: "BaustelleUserService", environment_name: "staging-a63e0c95fe")
      expect(eb).to have_received(:describe_environments)
                .with(environment_names: ["staging-a63e0c95fe"])
    end

    it "uses a different stack name if passed" do
      expect { run(["script", "systemtest-env", "user_service", "staging", "--stack=Foo"]) }.to output(generate_env("http", cname)).to_stdout

      expect(eb).to have_received(:describe_configuration_settings)
                .with(application_name: "FooUserService", environment_name: "staging-a27063ede5")
      expect(eb).to have_received(:describe_environments)
                .with(environment_names: ["staging-a27063ede5"])
    end

    context "with custom dns" do
      let(:app_config) {
        {'dns' => {'name' => 'custom-foo-domain'}}
      }

      it "displays the environment variables and the custom dns name in APPLICATION_URL" do
        expect { run(["script", "systemtest-env", "user_service", "staging"]) }.to output(generate_env("http","custom-foo-domain")).to_stdout

        expect(eb).to have_received(:describe_configuration_settings)
                  .with(application_name: "BaustelleUserService", environment_name: "staging-a63e0c95fe")
        expect(eb).not_to have_received(:describe_environments)
      end
    end

    context "using https" do
      let(:app_config) {
        {'elb' => {'https' => true}}
      }

      it "uses https://<cname> as APPLICATION_URL" do
        expect { run(["script", "systemtest-env", "user_service", "staging"]) }.to output(generate_env("https", cname)).to_stdout
      end
    end

    context "using https and custom dns" do
      let(:app_config) {
        { 'elb' => {'https' => true}, 'dns' => {'name' => 'custom-foo-domain'} }
      }
      
      it "uses https://<custom dns> as APPLICATION_URL" do
        expect { run(["script", "systemtest-env", "user_service", "staging"]) }.to output(generate_env("https", "custom-foo-domain")).to_stdout
      end
    end

    context "specifying environment variable names that should be included from the application" do
      let(:app_config) {
        {'systemtests' => { 'config_from_application_whitelist' => ["FOO_VAR", "FOO_VAR2"] }}
      }

      it "includes the configured environment variables in the output" do
        expect { run(["script", "systemtest-env", "user_service", "staging"]) }.to output(
<<-ENV
FOO_VAR=bar
FOO_VAR2=bar2
APPLICATION_URL=http://#{cname}
HOST=http://#{cname}
ENV
        ).to_stdout
      end
    end

    it "uses the default region" do
      silence_stream(STDOUT) { run(["script", "systemtest-env", "user_service", "staging"]) }

      expect(Aws.config[:region]).to eq('us-east-1')
    end

    it "uses a different region if passed" do
      silence_stream(STDOUT) { run(["script", "systemtest-env", "user_service", "staging", "--region=foo-region"]) }

      expect(Aws.config[:region]).to eq('foo-region')
    end
  end


  private

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

  def generate_env(protocol, dns)
<<-ENV
APPLICATION_URL=#{protocol}://#{dns}
HOST=#{protocol}://#{dns}
ENV
  end

  def run(*args)
    Baustelle::CLI.start(*args)
  end

end
