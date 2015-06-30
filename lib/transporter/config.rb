module Transporter
  class Config
    attr_reader :records_to_extract, :foo

    def initialize
      @records_to_extract = nil
    end

    def configure_records_to_extract(&block)
      @records_to_extract = block
    end

    def records_to_extract(prev_extracted_records)
      unless @records_to_extract.present?
        raise "No proc defined for extracting records to be transported. Please configure this as port of the environment initialization."
      end

      records = @records_to_extract.call(prev_extracted_records)
    end
  end
end
