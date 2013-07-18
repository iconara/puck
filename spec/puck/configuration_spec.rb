# encoding: utf-8

require 'spec_helper'


module Puck
  describe Configuration do
    describe '#get' do
      it 'returns the default configuration when ARGV is empty' do
        described_class.new(argv: []).get.should == {}
      end

      context 'with command line arguments' do
        it 'returns a list of extra files' do
          config = described_class.new(argv: %w[--extra-files config/app.yml config/db.yml foo/bar]).get
          config[:extra_files].should == %w[config/app.yml config/db.yml foo/bar]
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
