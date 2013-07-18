# encoding: utf-8

require 'spec_helper'


module Puck
  describe Configuration do
    describe '#get' do
      it 'returns the default configuration when ARGV is empty' do
        described_class.new(argv: []).get.should == {}
      end

      context 'with command line arguments' do
        it 'sets :extra_files option to the list of files specified after --extra-files' do
          config = described_class.new(argv: %w[--extra-files config/app.yml config/db.yml foo/bar]).get
          config[:extra_files].should == %w[config/app.yml config/db.yml foo/bar]
        end

        it 'sets the :base_dir option to the value of --base-dir' do
          config = described_class.new(argv: %w[--app-dir /hello/world]).get
          config[:app_dir].should == '/hello/world'
        end

        it 'sets the :build_dir option to the value of --build-dir' do
          config = described_class.new(argv: %w[--build-dir /hello/world]).get
          config[:build_dir].should == '/hello/world'
        end

        it 'sets the :app_name option to the value of --app-name' do
          config = described_class.new(argv: %w[--app-name foo]).get
          config[:app_name].should == 'foo'
        end

        it 'sets the :jruby_complete option to the value of --jruby-complete' do
          config = described_class.new(argv: %w[--jruby-complete jruby-complete.jar]).get
          config[:jruby_complete].should == 'jruby-complete.jar'
        end

        it 'handles multiple command line flags together' do
          config = described_class.new(argv: %w[--app-name foo --extra-files foo/bar hello/world --build-dir plonk]).get
          config[:app_name].should == 'foo'
          config[:extra_files].should == %w[foo/bar hello/world]
          config[:build_dir].should == 'plonk'
        end
      end
    end

    describe '.get' do
      it 'is a shortcut for #new + #get' do
        config = described_class.get(argv: %w[--extra-files config/app.yml])
        config[:extra_files].should == %w[config/app.yml]
      end
    end
  end
end
