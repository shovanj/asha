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

  module ClassMethods

    def key(*args)
      unless args.empty?
        attr_name = args[0]
        @key ||= attr_name

        define_method(attr_name) do
          instance_variable_get("@#{attr_name.to_s}")
        end

        define_method("#{attr_name}=") do |value|
          instance_variable_set("@#{attr_name.to_s}", value)
        end
      end
      return @key
    end

  end

  class Model

    extend HelperMethods
    extend ClassMethods

    include InstanceMethods

  end

end
