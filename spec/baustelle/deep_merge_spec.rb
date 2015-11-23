require 'spec_helper'

describe "Hash#deep_merge" do
  it 'allows to override with false' do
    expect({foo: true}.deep_merge(foo: false)).
      to eq(foo: false)
  end
end
