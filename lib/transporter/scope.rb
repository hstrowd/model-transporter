module Transporter
  class Scope
    attr_reader :scoped_classes

    CONFIG_KEYS = [ :ids, :associations ]

    def initialize
      @scoped_classes = {}
    end

    def configure_class(klass, scope_config)
      @scoped_classes[klass] = scope_config.keep_if { |k,v| CONFIG_KEYS.include?(k) }
    end

    def seed_records
      seed_records = []

      @scoped_classes.each do |klass, config|
        next unless config[:ids]
        seed_records << klass.where(id: config[:ids]).to_a.compact
      end
      
      return seed_records.flatten
    end

    def records_for(klass)
      scope_config = @scoped_classes[klass]
      return nil unless scope_config
      return scope_config[:ids]
    end

    def associations_for(klass)
      scope_config = @scoped_classes[klass]
      return nil unless scope_config
      return scope_config[:associations]
    end
  end
end
