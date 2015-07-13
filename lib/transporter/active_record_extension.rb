require 'sneaky-save'
require 'transporter/result'
require 'transporter/utils'

module Transporter
  module ActiveRecordExtension
    extend ActiveSupport::Concern

    def self.debug=(enabled)
      @debug = enabled
    end

    def self.log(msg)
      puts msg if @debug
    end

    REQUIRED_VALIDATORS = []
    REQUIRED_VALIDATORS << ActiveModel::Validations::PresenceValidator if defined? ActiveModel::Validations::PresenceValidator
    REQUIRED_VALIDATORS << ActiveRecord::Validations::PresenceValidator if defined? ActiveRecord::Validations::PresenceValidator

    included do
      def transport(target_db, result = Result.new)
        klass = self.class
        source_db = klass.connection_config

        klass.establish_connection(target_db)
        return if result.contains?(klass, id)

        result.add_pending_record(klass, id)

        # It is insufficient to use `new` here in case there are
        # initialization callbacks that will not be fulfilled.
        new_object = self.dup
        begin
          new_object.assign_attributes(attributes, without_protection: true)
        rescue ArgumentError => e
          # Newer versions of assign_attributes do not support the second options parameter.
          new_object.assign_attributes(attributes)
        end

        ActiveRecordExtension.log("Transporting #{klass.to_s} #{id} to target DB.")
        klass.connection.execute("SET foreign_key_checks = 0;")
        begin
          # Note: I tried to use skip_callback and the validate option on save!, but this did not work with the complex set of
          #   callbacks we have in place. As a fallback, I decided to use this gem instead.
          new_object.sneaky_save!
        rescue => e
          # nil indicates that the record failed to be transported.
          return { klass.to_s => { id => nil } }
        ensure
          klass.connection.execute("SET foreign_key_checks = 1;")
        end

        result.add_created_record(klass, id)

        klass.establish_connection(source_db)
        transport_associated_records(target_db, result)

        return result
      ensure
        # Without this, subsequent association lookups would potentially be performed on the target DB instead of the source DB.
        klass.establish_connection(source_db)
      end

      private

      def transport_associated_records(target_db, result)
        klass = self.class
        created_records = {}

        acceptable_associations = Transporter.config.scope.associations_for(klass)
        klass.reflections.each do |association_name, association_desc|
          if acceptable_associations && !acceptable_associations.include?(association_name)
            ActiveRecordExtension.log("Skipping #{association_name} for #{klass.to_s} becaues it is not in scope.")
            next
          end

          ActiveRecordExtension.log("Retrieving #{association_name} for #{klass.to_s} #{id}.")
          association = send(association_name)
          begin
            association_class = association_desc.klass
          rescue NameError => ne
            # For polymorphic associations the klass will not be found.
          end

          if association_desc.collection?
            # Don't transport records outside of the defined scope.
            association_class = association.first.class if association_class.nil?
            acceptable_records = Transporter.config.scope.records_for(association_class)

            if acceptable_records.present?
              association = association.where(id: acceptable_records)
              ActiveRecordExtension.log("Limiting #{klass.to_s} #{association_name} to only the specified scope.")
            end

            association.limit(Transporter.config.max_association_count).each do |associated_record|
              associated_record.transport(target_db, result)
            end
          else
            next unless association.present?

            # Don't transport records outside of the defined scope.
            association_class = association.class if association_class.nil?
            acceptable_records = Transporter.config.scope.records_for(association_class)
            if acceptable_records.present? && !acceptable_records.include?(association.id)
              ActiveRecordExtension.log("Skipping #{klass.to_s} #{association_name} #{association.id} because it is not in scope.")
              next
            end

            association.transport(target_db, result)
          end
        end

        return result
      end
    end
  end
end

# Add the extension to AR models
ActiveRecord::Base.send(:include, Transporter::ActiveRecordExtension) if defined? ActiveRecord::Base
