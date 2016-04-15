require 'test_helper'

class A
  extend Asha::HelperMethods
end

describe Asha::HelperMethods do

  it "should return hash_key" do
    hash_key_using_class = A.hash_key("test", :source)
    hash_key_computed = "source:#{Digest::SHA1.hexdigest 'test' }"
    expect(hash_key_using_class).must_equal(hash_key_computed)
  end

end
