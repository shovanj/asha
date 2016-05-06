require 'test_helper'

describe Asha::HelperMethods do

  it "should test hash_key" do
    @helper = Object.new
    @helper.extend(Asha::HelperMethods::ClassMethods)

    hash_key_computed = "source:#{Digest::SHA1.hexdigest 'test' }"
    expect(@helper.hash_key("test", :source)).must_equal(hash_key_computed)
  end

  it "should test hash_key when custom class responds to a method call from module" do
    class Document < Asha::Model;end
    object = Document.new({})
    object.extend(Asha::HelperMethods::ClassMethods)

    class << object
      key(:url, :docx)
    end

    hash_key_computed = "docx:#{Digest::SHA1.hexdigest('test')}"
    expect(object.hash_key("test", :source)).wont_equal(hash_key_computed)
    expect(object.hash_key("test", :document)).wont_equal(hash_key_computed)
    expect(object.hash_key("test", :docx)).must_equal(hash_key_computed)
    expect(object.hash_key("test")).must_equal(hash_key_computed)
  end

end
