require_relative "asha/version"
require 'digest'
require 'redis'
require 'base64'

module Asha

  def self.establish_connection(conn)
    raise "Please specify database." unless conn[:db]
    @redis ||= Redis.new(
                        host: conn[:host],
                        port: conn[:port] || 6379,
                        db: conn[:db]
    )
  end

  def self.database
    raise 'Please establish connection to redis.' unless @redis
    @redis
  end

  module HelperMethods

    def self.included(base)
      base.extend(ClassMethods)
    end

    def klass_name
      self.class.name.downcase
    end

    def db
      Asha.database
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
    attr_reader :id
    attr_reader :persisted

    def initialize(attrs)
      attrs.each do |k,v|
        if respond_to? "#{k}="
          instance_variable_set("@#{k}", v)
        end
      end
      @persisted = false
    end

    def set
      @set ||= klass_name
    end

    def sorted_set
      @sorted_set ||= "z#{set}"
    end


    def identifier
      @identifier ||= "#{klass_name}:#{id}"
    end

    def exists?
      db.exists(identifier)
    end

    def new?
      !exists?
    end

    def save
      new_record = new?
      if new_record && !db.sismember(klass_name, set_member_id)
        persist_in_db(true)
        add_to_sets
      elsif new_record && db.sismember(klass_name, set_member_id)
        p "An error has occured"
      elsif !new_record
        # TODO: I don't like the method name here
        persist_in_db
      end
      self
    end

    def update(values)
      raise "Please save the record first." unless @persisted
      # TODO: sanitize values param
      values.each do |key, value|
        if self.class.attributes.include?(key)
          instance_variable_set("@#{key}", value)
        end
      end
      persist_in_db
      self
    end

    def id
      @id ||= (instance_variable_get(:@id) || next_available_id)
    end

    def set_member_id
      if self.class.key
        Base64.strict_encode64(instance_variable_get("@#{self.class.key}"))
      else
        @id
      end
    end

    private

    def next_available_id
      return db.incr "#{klass_name}:id_counter"
    end

    def persist_in_db(new_record=false)
      instance_variables.each do |v|
        next if v == :@identifier
        next if v == :@id
        next if v == :@persisted
        db.hset(
            identifier,
            v.to_s.gsub('@',''),
            instance_variable_get(v)
        )
      end
      if new_record
        db.hset(identifier, "id", @id)
        db.hset(identifier, 'created_at', Time.now)
      end
      db.hset(identifier, 'updated_at', Time.now)
      @persisted = true
    end

    def add_to_sets
      db.zadd("z#{klass_name}", Time.now.to_i, @id)
      db.sadd(klass_name, set_member_id)
    end

  end

  module ClassMethods

    attr_accessor :attributes

    def db
      Asha.database
    end

    def create(attrs)
      self.new(attrs)
    end

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

    def set(set_name)
      @sets = [] if @sets.nil?
      @sets << set_name

      self.class_eval do
        define_method set_name do
          unless instance_variable_defined?("@#{set_name}")
            set = instance_variable_set("@#{set_name}", Set.new)
            yield(set) if block_given?
            if set.sorted
              set.id = "z#{identifier}:#{set_name}"
            else
              set.id = "#{identifier}:#{set_name}"
            end
          end
          instance_variable_get("@#{set_name}")
        end
      end

      @sets.uniq!
    end

    def find(id)
      hash = db.hgetall("#{self.name.downcase}:#{id}")
      if !hash.empty?
       record = self.new(hash)
       record.instance_variable_set(:@persisted, true)
       record.instance_variable_set(:@id, id)
       record
      end
    end

    def all
      db.zrevrange("z#{self.name.downcase}", 0, -1).inject([]) do |result, r|
        result << self.find(r)
      end
    end
  end

  class Model

    include HelperMethods
    extend ClassMethods

    include InstanceMethods

  end

  class Set

    attr_accessor :id
    attr_accessor :sorted

    include Enumerable
    include HelperMethods

    def initialize()
      @members = []
    end

    def each(&block)
      @members.each do |member|
        block.call(member)
      end
    end


    # TODO: how to handle when model is not in db yet
    def add(model)
      raise "Invalid data" unless model.is_a? Asha::Model
      raise "Object not persisted" unless model.persisted
      result = if sorted
                 db.zadd("#{id}", Time.now.to_i, model.id)
               else
                 db.sadd(id, model.id)
               end
      @members << model if result
    end
    alias_method :<<, :add

  end


end
