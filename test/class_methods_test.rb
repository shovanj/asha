require 'test_helper'

class Source < Asha::Model

  attribute :title
  attribute :url

  key :url

  set :posts

  set :authors

end

describe Asha::ClassMethods do

  let(:params) do
    {title: "The New Blog", url: "http://localhost/atom2.xml"}
  end

  let(:object) do
    Source.new(params)
  end

  def setup
    Asha.database.srem("source", object.set_member_id) # TODO: find a better way
  end

  describe "#key" do
    it "should respond to 'key' method" do
      expect(Source).must_respond_to "key"
    end

    it "should return correct value for 'key'" do
      expect(Source.key).must_equal :url
    end

    it "should add key attribute to set named after the class" do
      identifier = object.identifier
      db = Minitest::Mock.new
      db.expect(:sismember, true, [String, String])
      db.expect(:sismember, false, [String, String])
      db.expect(:exists, false, [identifier])
      params.each do |key, value|
        db.expect(:hset, nil, [identifier, key.to_s, value])
      end

      db.expect(:hset, nil, [identifier, "id", object.id])
      db.expect(:hset, nil, [identifier, "created_at", Time])
      db.expect(:hset, nil, [identifier, "updated_at", Time])
      db.expect(:zadd, nil, ["zsource", Fixnum, object.id])
      db.expect(:sadd, nil, ["source", String])

      object.stub("db", db) do
        object.save
      end
    end
  end

  describe "#attribute" do
    it "should respond to 'attribute'" do
      expect(Source).must_respond_to "attribute"
    end

    # TODO: create custom matcher to compare array
    it "should set given attributes to instance variable" do
      expected_result = [:title, :url].sort
      expect(Source.instance_variable_get("@attributes").sort).must_equal(expected_result)
    end

    it "should respond to defined attributes" do
      expect(object).must_respond_to "title"
      expect(object).must_respond_to "created_at"
      expect(object).must_respond_to "created_at"
      expect(object).wont_respond_to "age"
    end

 end

  describe ".set" do
    it "should do something" do
      expect(Source.instance_variable_get('@sets').sort).must_equal([:posts, :authors].sort)
    end
  end

  describe ".find" do

    let(:object) do
      Source.new({title: "News", url: "http://localhost"})
    end

    it "should respond to find" do
      expect(Source).must_respond_to "find"
    end

    it "should return an object" do
      object.save
      source = Source.find(object.id)
      expect(source).must_be_kind_of Source
      expect(source.title).must_equal "News"
    end

  end

  def teardown
    Asha.database.hgetall(object.identifier).each do |k,v|
      Asha.database.hdel(object.identifier, k)
    end
  end
end

