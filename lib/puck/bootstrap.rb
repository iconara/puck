if ARGV.any?
  file_name = ARGV.shift
  bootstrap_path = __FILE__.sub('jar-bootstrap.rb', "META-INF/app.home/bin/#{file_name}")
  begin
    load(bootstrap_path)
  rescue LoadError => e
    abort(e.message)
  end
end
 