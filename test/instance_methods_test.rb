require_relative 'test_helper'

class Source < Asha::Model

  attribute :title
  attribute :url

  key :url

  set :posts

  set :authors

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
    end

    it "should call 'hset' on redis with correct params" do
      object.stub("next_available_id", 1) do
        db = Minitest::Mock.new
        db.expect(:sismember, false, [String, String])
        db.expect(:sismember, false, [String, String])
        db.expect(:exists, false, ['source:1'])

        params.each do |key, value|
          db.expect(:hset, nil, ['source:1', key.to_s, value])
        end

        db.expect(:hset, nil, ['source:1', "id", 1])
        db.expect(:hset, nil, ['source:1', "created_at", Time])
        db.expect(:hset, nil, ['source:1', "updated_at", Time])
        db.expect(:zadd, nil, ["zsource", Fixnum, 1])
        db.expect(:sadd, nil, ["source", Base64.strict_encode64(params[:url])])
        object.stub("db", db) do
          object.save
        end
      end
    end


  end

  describe "#update" do

    it "should respond to #save" do
      expect(object).must_respond_to "update"
    end

    it "should update redis hash with correct values" do
      object.save

      identifier = object.identifier
      new_attrs = {title: "Awesome new title", url: "http://localhost/rss"}
      db = Minitest::Mock.new
      db.expect(:exists, true, [identifier])

      new_attrs.each do |key, value|
        db.expect(:hset, nil, [identifier, key.to_s, value])
      end


      db.expect(:hset, nil, [identifier, "updated_at", Time])

      object.stub("db", db) do
        object.update(new_attrs)
      end

    end

    # TODO: create a specific error, not just runtime
    it "should raise an error if update is called on unsaved record" do
      -> { object.update({}) }.must_raise RuntimeError
    end

  end

  describe "set related methods" do

    describe "sorted/unsorted set" do
      it "should call 'zrevrange' on redis with correct params" do
        identifier = object.identifier
        mocked_db = Minitest::Mock.new
        mocked_db.expect('zrevrange', nil, ["z#{identifier}:posts", 0, -1])

        object.stub('db', mocked_db) do
          object.posts
        end
      end

      it "should call 'smembers' with correct params" do
        identifier = object.identifier
        mocked_db = Minitest::Mock.new
        mocked_db.expect('smembers', nil, ["#{identifier}:authors"])

        object.stub('db', mocked_db) do
          object.authors
        end
      end
    end

  end

  describe '#delete' do
    it 'should respond to delete' do
      expect(object).must_respond_to 'delete'
    end

    it 'should call delete key and remove from set' do
      identifier = object.identifier
      mocked_db = Minitest::Mock.new
      mocked_db.expect('del', true, [identifier])
      mocked_db.expect('srem', true, [object.set, object.set_member_id])
      mocked_db.expect('zrem', true, [object.sorted_set, object.id])

      object.stub('db', mocked_db) do
        object.delete
      end

    end
  end

  def teardown
    Asha.database.smembers("source").each do |v|
      Asha.database.srem("source", v) # TODO: find a better way
    end
    Asha.database.hgetall(object.identifier).each do |k,v|
      Asha.database.hdel(object.identifier, k)
    end
  end

end
