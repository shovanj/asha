require 'test_helper'

class Source < Asha::Model

  attribute :title
  attribute :url
  attribute :updated_at
  attribute :created_at

  key :url

end

describe Asha::ClassMethods do

  let(:object) do
    Source.new
  end

  describe "#key" do
    it "should respond to 'key' method" do
      expect(Source).must_respond_to "key"
    end

    it "should return correct value for 'key'" do
      expect(Source.key).must_equal :url
    end

  end

  describe "#attribute" do

    it "should respond to 'attribute'" do
      expect(Source).must_respond_to "attribute"
    end

    # TODO: create custom matcher to compare array
    it "should set given attributes to instance variable" do
      expected_result = [:title, :updated_at, :url, :created_at].sort
      expect(Source.instance_variable_get("@attributes").sort).must_equal(expected_result)
    end

  end

end

