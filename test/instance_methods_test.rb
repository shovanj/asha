require 'test_helper'

class Source < Asha::Model

  key :url

end

describe Asha::InstanceMethods do

  let(:object) do
    Source.new
  end

  it "should return 'source' as set name" do
    expect(object.set).must_equal "source"
  end

  it "should return 'zsource' as sorted set name" do
    expect(object.sorted_set).must_equal 'zsource'
  end

  it "should return unique attribute" do
    expect(Source.key).must_equal(:url)
  end

end
