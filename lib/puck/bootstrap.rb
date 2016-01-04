if ARGV.any?
  file_name = ARGV.shift
  bin_file_found = false
  PUCK_BIN_PATH.each do |dir|
    absolute_path = File.join(PUCK_ROOT, dir, file_name)
    if File.exists?(absolute_path)
      bin_file_found = true
      $0 = absolute_path
      load(absolute_path)
      break
    end
  end
  unless bin_file_found
    abort(%(No "#{file_name}" in #{PUCK_BIN_PATH.join(File::PATH_SEPARATOR)}))
  end
end
