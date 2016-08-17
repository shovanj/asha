module Asha
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
end
