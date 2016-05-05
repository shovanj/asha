require "asha/version"
require 'digest'

module Asha

  module HelperMethods

    def self.included(base)
      base.extend(ClassMethods)
    end

    def klass_name
      self.class.name.downcase
    end

    module ClassMethods

      def hash_key(base, prefix=nil)
        key = Digest::SHA1.hexdigest(base)
        if prefix.nil? && self.respond_to?(:key_prefix)
          "#{self.key_prefix}:#{key}"
        elsif prefix
          "#{prefix}:#{key}"
        else
          key
        end
      end

    end
  end

  module InstanceMethods


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

        if prefix = args[1]
          define_method("key_prefix") do
            prefix
          end
        end
      end
      return @key
    end

  end

  class Model

    include HelperMethods
    extend ClassMethods

    include InstanceMethods

  end

end
