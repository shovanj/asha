require 'test_helper'

class Source < Asha::Model

  attribute :title
  attribute :created_at
  attribute :url

  key :url

end

describe Asha::InstanceMethods do

  let(:object) do
    Source.new({title: "The New Blog", created_at: Time.now.to_s, url: "http://localhost/atom.xml"})
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

  describe "#initialize" do
    it "should have correct instance values after initialization" do
      expect(object.title).must_equal("The New Blog")
      expect(object.url).must_equal("http://localhost/atom.xml")
    end
  end

end
