require 'spec_helper'
require 'tempfile'

module Baustelle
  describe Config do
    def write_config(filename, content)
      Tempfile.open('config.yml') do |config_file|
        begin
          config_file.puts content
          config_file.close
          yield config_file.path
        ensure
          config_file.close
          config_file.unlink
        end
      end
    end

    describe '#read' do
      it 'reads the YAML file' do
        write_config('config.yml', <<-YAML) do |path|
---
name: Hello
            YAML
          expect(Config.read(path)).to eq({'name' => 'Hello'})
        end
      end

      it 'allows to include other config files' do
        write_config('include.yml', <<-YAML) do |include_path|
---
name: Hello
YAML
          write_config('config.yml', <<-YAML) do |path|
---
foo: include(#{include_path})
config:
  nested: include(#{include_path})
YAML
            expect(Config.read(path)).
              to eq({
                      'foo' => {'name' => 'Hello'},
                      'config' => {
                        'nested' => {'name' => 'Hello'}
                      }
                    })
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
