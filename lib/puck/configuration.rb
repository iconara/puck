# encoding: utf-8

require 'optparse'


module Puck
  class Configuration
    def initialize(defaults={})
      @argv = defaults[:argv] || ARGV
    end

    def self.get(defaults={})
      new(defaults).get
    end

    def get
      command_line_options
    end

    private

    def command_line_options
      options = {}

      state = nil

      until @argv.empty?
        arg = @argv.shift
        case arg
        when '--extra-files'
          state = :extra_files
          options[:extra_files] ||= []
        else
          case state
          when :extra_files
            options[:extra_files] << arg
          end
        end
      end

      options
    end
  end
end