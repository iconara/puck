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
        when '--app-name', '--app-dir', '--build-dir', '--jruby-complete'
          state = arg.sub(/^--/, '').gsub('-', '_').to_sym
        else
          case state
          when :extra_files
            options[:extra_files] << arg
          when :app_name, :app_dir, :build_dir, :jruby_complete
            options[state] = arg
            state = nil
          end
        end
      end

      options
    end
  end
end