require 'json'

module Transporter
  module Utils
    def self.deep_merge!(base, addition)
      return base if addition.nil?
      merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : v2 }
      base.merge!(addition, &merger)
    end

    def self.load_json_file(file_path)
      return if file_path.nil? || !File.exists?(file_path)

      JSON.parse(File.read(file_path))
    end
  end
end
