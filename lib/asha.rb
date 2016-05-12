require_relative "asha/version"
require 'digest'
require 'redis'

module Asha

  def self.database
    @redis ||= Redis.new(
        :host => "127.0.0.1",
        :port => 6379,
        :db => 1 # TODO: Fix me ENV['DATABASE']
    )
  end

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

    attr_reader :created_at
    attr_reader :updated_at

    def initialize(attrs)
      attrs.each do |k,v|
        if respond_to? "#{k}="
          instance_variable_set("@#{k}", v)
        end
      end
    end

    def set
      @set ||= klass_name
    end

    def sorted_set
      @sorted_set ||= "z#{set}"
    end

    def db
      Asha.database
    end

    def identifier
      @identifier ||= "#{klass_name}:#{id_for_object}"
    end

    def exists?
      db.exists(identifier)
    end

    def new?
      !exists?
    end

    def save
      new_record = new?
      instance_variables.each do |v|
        next if v == :@identifier
        db.hset(
            identifier,
            v.to_s.gsub('@',''),
            instance_variable_get(v)
        )
      end
      db.hset(identifier, 'created_at', Time.now) if new_record
      db.hset(identifier, 'updated_at', Time.now)
    end

    private

    def id_for_object
      if defined?(self.id)
        self.id
      else
        next_available_id
      end
    end

    def next_available_id
      return db.incr "#{klass_name}:id_counter"
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

    def attribute(attribute_name)
      @attributes = [] if @attributes.nil?
      self.class_eval { attr_accessor attribute_name }
      @attributes << attribute_name
      @attributes.uniq!
    end

  end

  class Model

    include HelperMethods
    extend ClassMethods

    include InstanceMethods

  end

end
