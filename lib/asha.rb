require_relative "asha/version"
require 'digest'
require 'redis'
require 'base64'

module Asha

  require 'asha/helper_methods'
  require 'asha/class_methods'
  require 'asha/instance_methods'

  class SetMemberError < RuntimeError
    def initialize(record, msg="Record with given data already exists.")
      super("#{record.inspect} => #{msg} ")
    end
  end

  # Establishes connection
  #
  # @param conn [Hash] the hash object needs :db, :host
  # @return a redis database
  def self.establish_connection(conn)
    raise "Please specify database." unless conn[:db]
    @redis ||= Redis.new(
                        host: conn[:host],
                        port: conn[:port] || 6379,
                        db: conn[:db]
    )
  end

  # @return instance of redis database
  def self.database
    raise 'Please establish connection to redis.' unless @redis
    @redis
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
