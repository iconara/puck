if ARGV.any?
  file_name = ARGV.shift
  PUCK_BIN_PATH.each do |dir|
    path = __FILE__.sub('jar-bootstrap.rb', File.join(dir, file_name))
    if File.exists?(path)
      $0 = path
      load(path)
      return
    end
  end
  abort(%(No "#{file_name}" in #{PUCK_BIN_PATH.join(File::PATH_SEPARATOR)}))
end
 