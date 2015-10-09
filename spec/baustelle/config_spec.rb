require 'spec_helper'
require 'tempfile'

module Baustelle
  describe Config do
    describe '#read' do
      it 'reads the YAML file' do
        Tempfile.open('config.yml') do |config_file|
          begin
            config_file.puts <<-YAML
---
name: Hello
            YAML
            config_file.close

            expect(Config.read(config_file.path)).to eq({'name' => 'Hello'})

          ensure
            config_file.close
            config_file.unlink
          end
        end
      end
    end

    describe '#for_environment' do
      subject { ->(env) { Config.for_environment(config, env) } }

      let(:config) {
        {
          'a' => {
            'b' => {
              'c' => 1
            }
          },
          'foo' => 'bar',
          'environments' => {
            'prod' => {
              'a' => {
                'b' => {
                  'c' => 2
                }
              }
            },
            'staging' => {
              'a' => {
                'b' => {
                  'c' => 0
                }
              }
            }
          }
        }
      }

      context 'when environment overrides exist' do
        it 'replaces the overriden values' do
          expect(subject.('staging')['a']['b']['c']).to eq(0)
          expect(subject.('prod')['a']['b']['c']).to eq(2)

        end

        it 'does not change global values' do
          expect(subject.('prod')['foo']).to eq('bar')
        end

        it 'removes the "environments" key' do
          expect(subject.('prod')).not_to have_key('environments')
        end
      end
    end
  end
end
