require 'test_helper'

class A
  extend Asha::HelperMethods
end

class AshaHelperMethodsTest < Minitest::Test

  # Called before every test method runs. Can be used
  # to set up fixture information.
  def setup
    # Do nothing
  end

  # Called after every test method runs. Can be used to tear
  # down fixture information.

  def teardown
    # Do nothing
  end

  # Fake test
  def test_hash_key
    url = "www.example.com/rss"
    hash_key = Digest::SHA1.hexdigest(url)
    assert_equal "source:#{hash_key}", A.hash_key(url, :source)
  end

end

