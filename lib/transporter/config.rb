require 'transporter/scope'

module Transporter
  class Config
    attr_accessor :max_association_count
    attr_reader :records_to_transport, :scope

    def initialize
      @max_association_count = 25
      @records_to_transport = nil
      @scope = Scope.new
    end

    def configure_records_to_transport(&block)
      @records_to_transport = block
    end

    def records_to_transport(prev_transported_records)
      unless @records_to_transport.present?
        raise "No proc defined for extracting records to be transported. Please configure this as port of the environment initialization."
      end

      @records_to_transport.call(@scope, prev_transported_records)

      records = @scope.seed_records
    end
  end
end
