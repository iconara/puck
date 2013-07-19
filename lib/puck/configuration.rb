# encoding: utf-8

require 'optparse'


module Puck
  # @private
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

    SCALAR_ARGS = [:app_name, :app_dir, :build_dir, :jruby_complete].freeze
    LIST_ARGS = [:extra_files].freeze
    ARG_PREFIX = '--'.freeze

    def command_line_options
      state = nil
      option = nil
      @argv.each_with_object({}) do |arg, options|
        if arg.start_with?(ARG_PREFIX)
          option = arg.sub(/^--/, '').gsub('-', '_').to_sym
          if LIST_ARGS.include?(option)
            options[option] = []
            state = :list
          else
            state = :scalar
          end
        else
          case state
          when :list
            options[option] << arg
          when :scalar
            options[option] = arg
            option = nil
            state = nil
          end
        end
      end
    end
  end
end