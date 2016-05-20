require 'spec_helper'
require 'tempfile'

describe Baustelle::Jenkins::JobTemplate do


  let(:template) {
<<-TEMPLATE
job('jobName') {
  steps {
    shell('echo 1')
  }
}
TEMPLATE
  }

  let(:template_with_syntax_errors) {
<<-TEMPLATE
job('jobName') {
  steps {
    shell('echo 1')
  }
  }
}
TEMPLATE
  }


  it 'should render the template without errors' do
    job_template = Baustelle::Jenkins::JobTemplate.new(template,'')
    expect {job_template.render()}.to_not raise_exception
  end

  it 'should render the template with errors' do
    job_template = Baustelle::Jenkins::JobTemplate.new(template_with_syntax_errors,'')
    expect {job_template.render()}.to raise_exception(Exception, 'Error during job DSL rendering')
  end


end
