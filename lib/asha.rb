require_relative "asha/version"
require 'digest'
require 'redis'
require 'base64'

module Asha

  class SetMemberError < RuntimeError
    def initialize(record, msg="Record with given data already exists.")
      super("#{record.inspect} => #{msg} ")
    end
  end

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

    # @return [Boolean] indicates whether object has been stored in database
    # attr_reader :persisted


    def initialize(attrs=nil)
      self.class.attributes.each do |attr|
        val = if attrs && attrs.include?(attr)
                attrs[attr]
              end
        instance_variable_set("@#{attr}", val)
      end
    end

    def persisted
      !id.nil?
    end
    def set
      @set ||= klass_name
    end

    def sorted_set
      @sorted_set ||= "z#{set}"
    end

    def identifier
      "#{klass_name}:#{id}"
    end

    # returns [String] which is the key attribute
    # eg: In following 'url' will be returned
    #  class Source
    #     attribute :name
    #     attribute :url
    #     key: url
    #  end
    def key_attribute
      self.class.key
    end

    def exists?
      return false if id.nil?
      db.exists(identifier)
    end

    def new?
      !exists?
    end

    def member_of_set?
      db.sismember(klass_name, set_member_id)
    end

    def save
      new_record = new?
      if new_record && member_of_set?
        raise Asha::SetMemberError.new(self, "Record with key '#{set_member_id}(#{instance_variable_get("@#{key_attribute}")})' value already exists in '#{klass_name}'")
      elsif new_record
        persist_in_db(true)
      elsif !new_record
        # TODO: I don't like the method name here
        persist_in_db
      end

      add_to_sets if !member_of_set?

      self
    end

    def update(values)
      raise "Please save the record first." unless persisted
      # TODO: sanitize values param
      values.each do |key, value|
        if self.class.attributes.include?(key)
          instance_variable_set("@#{key}", value)
        end
      end
      persist_in_db
      self
    end

    def set_member_id
      if key_attribute && instance_variable_get("@#{key_attribute}")
        Base64.strict_encode64(instance_variable_get("@#{key_attribute}"))
      else
        id
      end
    end

    private

    def next_available_id
      return db.incr "#{klass_name}:id_counter"
    end

    def persist_in_db(new_record=false)
      @id = next_available_id if new_record

      instance_variables.each do |v|
        next if v == :@identifier
        next if v == :@id
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
    end

    def add_to_sets
      db.zadd("z#{klass_name}", Time.now.to_i, @id)
      db.sadd(klass_name, set_member_id)
    end

  end

  module ClassMethods

    def db
      Asha.database
    end

    def create(attrs)
      self.new(attrs).save
    end

    def key(*args)
      @key ||= nil
      unless args.empty?
        attr_name = args[0]
        @key ||= attr_name

        unless defined?(attr_name)
          define_method(attr_name) do
            instance_variable_get("@#{attr_name.to_s}")
          end
        end

        unless defined?("#{attr_name}=")
          define_method("#{attr_name}=") do |value|
            instance_variable_set("@#{attr_name.to_s}", value)
          end
        end

        if prefix = args[1]
          define_method("key_prefix") do
            prefix
          end
        end
      end
      @key
    end

    def attribute(attribute_name)
      @attributes ||= []
      unless instance_methods.include?(attribute_name)
        self.class_eval { attr_accessor attribute_name }
        @attributes << attribute_name
      end
      @attributes.uniq!
    end

    def attributes
      @attributes ||= []
    end

    def set(set_name)
      @sets ||= []
      @sets << set_name

      self.class_eval do
        unless instance_methods.include?(set_name)
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
      end

      @sets.uniq!
    end

    def find(id)
      hash = db.hgetall("#{self.name.downcase}:#{id}")
      hash = hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

      if !hash.empty?
       record = self.new(hash)
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
      p "Can not add object to set. Save object first." and return unless model.persisted
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
