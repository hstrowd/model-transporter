require 'transporter/active_record_extension'
require 'transporter/config'

module Transporter
  def self.config
    @config ||= Config.new
  end

  def self.configure_transporter(&block)
    yield config
  end
end
