module Transporter
  class Config
    attr_reader :records_to_transport, :transport_scope

    def initialize
      @records_to_transport = nil
      @transport_scope = {}
    end

    def configure_records_to_transport(&block)
      @records_to_transport = block
    end

    def records_to_transport(prev_transported_records)
      unless @records_to_transport.present?
        raise "No proc defined for extracting records to be transported. Please configure this as port of the environment initialization."
      end

      @records_to_transport.call(@transport_scope, prev_transported_records)

      records = @transport_scope.collect do |klass, ids|
        klass.where(id: ids)
      end
      records.flatten
    end

    def scope_for(klass)
      @transport_scope[klass]
    end
  end
end
