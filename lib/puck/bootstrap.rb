file_name = Java::JavaLang::System.get_property('puck.entrypoint') || ARGV.shift

if file_name
  PUCK_BIN_PATH.each do |dir|
    relative_path = File.join(dir, file_name)
    if File.exists?("classpath:/#{relative_path}")
      $0 = relative_path
      load(relative_path)
      return
    end
  end
  abort(%(No "#{file_name}" in #{PUCK_BIN_PATH.join(File::PATH_SEPARATOR)}))
end
