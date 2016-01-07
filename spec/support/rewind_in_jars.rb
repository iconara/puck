# encoding: utf-8

module RewindInJars
  def self.behavior_after_gets
    File.open("classpath:/org/joda/time/format/messages.properties") do |f|
      first = f.gets
      f.rewind
      all = f.read
      if all.start_with?(first)
        :correct
      elsif all.empty?
        :discard
      else
        :ignore
      end
    end
  rescue
    :unknown
  end
end
