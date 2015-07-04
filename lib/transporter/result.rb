module Transporter
  class Result
    attr_reader :pending_records, :created_records

    def initialize
      @pending_records = {}
      @created_records = {}
    end

    def add_pending_record(klass, id)
      @pending_records[klass.to_s] ||= []
      @pending_records[klass.to_s] << id
    end

    def remove_pending_record(klass, id)
      @pending_records[klass.to_s] ||= []
      @pending_records[klass.to_s].delete(id)
    end

    def add_created_record(klass, id)
      @created_records[klass.to_s] ||= []
      @created_records[klass.to_s] << id
      remove_pending_record(klass, id)
    end

    def contains?(klass, id)
      pending_records_for_class = @pending_records[klass.to_s] || []
      return true if pending_records_for_class.include?(id)
      
      created_records_for_class = @created_records[klass.to_s] || []
      return true if created_records_for_class.include?(id)

      raise "ID Collision: ID #{id} for #{klass.to_s} already exists but was not apart of this transport." if klass.exists?(id)

      return false
    end
  end
end
