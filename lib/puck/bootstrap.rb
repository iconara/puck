if ARGV.any?
  file_name = ARGV.shift
  file_path = __FILE__.sub('jar-bootstrap.rb', "META-INF/app.home/bin/#{file_name}")
  if File.exists?(file_path)
    load(file_path)
  else
    abort("No #{file_name} in classpath:META-INF/app.home/bin")
  end
end
 