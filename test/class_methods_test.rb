require 'test_helper'

class Source < Asha::Model

  key :url

end

describe Asha::ClassMethods do

  let(:object) do
    Source.new
  end

  it "should respond to 'key' method" do
    expect(Source).must_respond_to "key"
  end

  it "should return correct value for 'key'" do
    expect(Source.key).must_equal :url
  end

end

