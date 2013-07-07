Gem::Specification.new do |gem|
  gem.authors = ["Logmind Developers"]
  gem.description = %q{Logmind is an integrated enterprise enabled big-data analytics system}
  gem.summary = %q{Logmind - machine generated data analytics}
  gem.homepage = "http://logmind.co/"
  gem.license = "MIT License"

  #gem.files = `git ls-files`.split($\)
  gem.name = "openmind"
  gem.require_paths = ["lib"]
  gem.version = "0.0.1"

  # Dependencies
gem.add_runtime_dependency 'sinatra'
gem.add_runtime_dependency 'haml'
gem.add_runtime_dependency 'json'
gem.add_runtime_dependency 'fastercsv'
gem.add_runtime_dependency 'tzinfo'
gem.add_runtime_dependency 'thin'
gem.add_runtime_dependency 'curb'
gem.add_runtime_dependency 'daemons'
#gem.add_runtime_dependency 'rpam'
gem.add_runtime_dependency 'net-ldap'
gem.add_runtime_dependency 'jls-grok'
gem.add_runtime_dependency 'tire'

gem.add_development_dependency 'rake'
gem.add_development_dependency 'rspec'
gem.add_development_dependency 'rspec-mocks'

end
