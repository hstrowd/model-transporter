require 'sneaky-save'
require 'transporter/utils'

module Transporter
  module ActiveRecordExtension
    extend ActiveSupport::Concern

    REQUIRED_VALIDATORS = []
    REQUIRED_VALIDATORS << ActiveModel::Validations::PresenceValidator if defined? ActiveModel::Validations::PresenceValidator
    REQUIRED_VALIDATORS << ActiveRecord::Validations::PresenceValidator if defined? ActiveRecord::Validations::PresenceValidator

    included do
      def transport(target_db, pending_records = {})
        klass = self.class
        source_db = klass.connection_config

        klass.establish_connection(target_db)
        return if klass.exists?(id) || (pending_records[klass.to_s] && pending_records[klass.to_s].include?(id))

        pending_records[klass.to_s] ||= []
        pending_records[klass.to_s] << id

        new_object = klass.new
        new_object.assign_attributes(attributes, without_protection: true)

        connection.execute("SET foreign_key_checks = 0;")
        begin
          # Note: I tried to use skip_callback and the validate option on save!, but this did not work with the complex set of
          #   callbacks we have in place. As a fallback, I decided to use this gem instead.
          new_object.sneaky_save!
        rescue => e
          # nil indicates that the record failed to be transported.
          return { klass.to_s => { id => nil } }
        ensure
          connection.execute("SET foreign_key_checks = 1;")
        end

        created_records = { klass.to_s => { id => new_object.id} }
        pending_records[klass.to_s].delete(id)

        klass.establish_connection(source_db)
        Utils.deep_merge!(created_records, transport_associated_records(target_db, pending_records))
        return created_records
      end

      private

      def transport_associated_records(target_db, pending_records)
        created_records = {}

        reflections.each do |association_name, association_desc|
          association = send(association_name)
          if association.present?
            Array.wrap(association).each do |associated_record|
              Utils.deep_merge!(created_records, associated_record.transport(target_db, pending_records))
            end
          end
        end

        return created_records
      end
    end
  end
end

# Add the extension to AR models
ActiveRecord::Base.send(:include, Transporter::ActiveRecordExtension) if defined? ActiveRecord::Base
