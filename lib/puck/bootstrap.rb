if ARGV.any?
  file_name = ARGV.shift
  found = false
  PUCK_BIN_PATH.each do |dir|
    path = __FILE__.sub('jar-bootstrap.rb', File.join(dir, file_name))
    if File.exists?(path)
      found = true
      load(path)
    end
  end
  unless found
    abort(%(No "#{file_name}" in #{PUCK_BIN_PATH.join(File::PATH_SEPARATOR)}))
  end
end
 