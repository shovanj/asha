require 'test_helper'

class Source < Asha::Model

  attribute :title
  attribute :url

  key :url

end

describe Asha::InstanceMethods do

  let(:params) do
    {title: "The New Blog", url: "http://localhost/atom.xml"}
  end

  let(:object) do
    Source.new(params)
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

  describe "#save" do
    it "should respond to #save" do
      expect(object).must_respond_to "save"
      object.save
    end

    it "should call 'hset' on redis with correct params" do
      identifier = object.identifier
      db = Minitest::Mock.new
      db.expect(:exists, false, [identifier])

      params.each do |key, value|
        db.expect(:hset, nil, [identifier, key.to_s, value])
      end

      db.expect(:hset, nil, [identifier, "created_at", Time])
      db.expect(:hset, nil, [identifier, "updated_at", Time])

      object.stub("db", db) do
        object.save
      end
    end
  end
end
