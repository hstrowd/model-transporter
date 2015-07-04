require 'active_record'
require 'transporter'
require 'transporter/utils'

namespace :model_transport do

  TRUE_BOOLEAN_VALUES = %w(true TRUE t T 1)

  desc 'pulls data in from an external source (e.g. staging)'
  task :load_from => :environment do |t, args|
    transported_records_file = ENV['TRANSPORTED_RECORDS_FILE']
    debug = TRUE_BOOLEAN_VALUES.include?(ENV['DEBUG'])
    source_db_adapter  = ENV['SOURCE_DB_ADAPTER'] || 'mysql2'
    source_db_name     = ENV['SOURCE_DB_NAME']
    source_db_host     = ENV['SOURCE_DB_HOST']
    source_db_user     = ENV['SOURCE_DB_USER']    || 'root'
    source_db_password = ENV['SOURCE_DB_PASSWORD']

    raise "Missing required source database name or host configuration." if source_db_name.nil? || source_db_host.nil?
    source_db_desc = {
      adapter:  'mysql2',
      database: source_db_name,
      host:     source_db_host,
      username: source_db_user,
      password: source_db_password
    }
    target_db_desc = ActiveRecord::Base.connection_config
    Transporter::ActiveRecordExtension.debug = debug

    prev_transported_records = Transporter::Utils.load_json_file(transported_records_file)
    ActiveRecord::Base.establish_connection(source_db_desc)
    records = Transporter.config.records_to_transport(prev_transported_records)
    raise "No records found to etract." unless records

    puts "Loading data from #{source_db_desc[:database]} at #{source_db_desc[:host]} into #{target_db_desc[:database]} at #{target_db_desc[:host]}" if debug

    result = Transporter::Result.new
    records.each do |record|
      puts "Transporting #{record.class.to_s} #{record.id}..." if debug
      record.transport(target_db_desc, result)
    end

    puts "RESULTS:\n=====\n"
    puts result.created_records.to_json
    puts "====="
  end

end
