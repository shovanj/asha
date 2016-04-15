require "asha/version"
require 'digest'

module Asha

  module HelperMethods

    def hash_key(base, prefix=nil)
      key = Digest::SHA1.hexdigest(base)
      prefix ? "#{prefix}:#{key}" : key
    end

  end

  module InstanceMethods

    def klass_name
      self.class.name.downcase
    end

    def set
      @set ||= klass_name
    end

    def sorted_set
      @sorted_set ||= "z#{set}"
    end

  end

  class Model
    extend HelperMethods
    include InstanceMethods
  end

end
