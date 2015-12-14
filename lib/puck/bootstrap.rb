if ARGV.any?
  file_name = ARGV.shift
  bin_file_found = false
  PUCK_BIN_PATH.each do |dir|
    relative_path = File.join(dir, file_name)
    if File.exists?("classpath:/#{relative_path}")
      bin_file_found = true
      $0 = relative_path
      load(relative_path)
      break
    end
  end
  unless bin_file_found
    abort(%(No "#{file_name}" in #{PUCK_BIN_PATH.join(File::PATH_SEPARATOR)}))
  end
end
