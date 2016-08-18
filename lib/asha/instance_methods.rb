module Asha
  module InstanceMethods

    # @return [Time] the time when object is created
    attr_reader :created_at

    # @return [Time] the time when object is updated
    attr_reader :updated_at

    # @return [Integer] value returned by redis incr command on a counter
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

    # @return [Boolean] indicates whether object has been stored in database
    def persisted
      !id.nil?
    end
    #
    # @return [String] name of the model class
    def set
      @set ||= klass_name
    end

    # This is  a test
    # @return [String] name of the sorted set based on set name with 'z' appended
    def sorted_set
      @sorted_set ||= "z#{set}"
    end

    # @return [String] which is used a unique key to retrieve data from redis
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

    # @return [Boolean] indicates whether key(identifier) exists in redis database
    def exists?
      return false if id.nil?
      db.exists(identifier)
    end

    # @return [Boolean] opposite of #exists?
    def new?
      !exists?
    end

    def member_of_set?
      db.sismember(klass_name, set_member_id)
    end

    # saves the instance in redis database
    # @return [Object]
    def save
      new_record = new?
      if new_record && member_of_set?
        raise Asha::SetMemberError.new(self, "Record with key '#{set_member_id}(#{instance_variable_get("@#{key_attribute}")})' value already exists in '#{klass_name}'")
      elsif new_record
        save_record(true)
      elsif !new_record
        save_record
      end

      add_to_sets unless member_of_set?

      self
    end

    def update(values)
      raise 'Please save the record first.' unless persisted
      # TODO: sanitize values param
      values.each do |key, value|
        if self.class.attributes.include?(key)
          instance_variable_set("@#{key}", value)
        end
      end
      save_record
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
      db.incr "#{klass_name}:id_counter"
    end

    def save_record(new_record=false)
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
end