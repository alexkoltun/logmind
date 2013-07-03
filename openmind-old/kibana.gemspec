Gem::Specification.new do |gem|
  gem.authors = ["Alex Koltun", "Omer Hanetz"]
  gem.description = %q{log search, visualization and analysis frontend for logstash+elasticsearch}
  gem.summary = %q{OpenMind - log search, visualization and analysis}
  gem.homepage = "http://logmind.co"
  gem.license = "MIT License"

  #gem.files = `git ls-files`.split($\)
  gem.name = "openmind"
  gem.require_paths = ["lib"]
  gem.version = "0.0.1"

  # Dependencies
gem.add_runtime_dependency 'sinatra'
gem.add_runtime_dependency 'json'
gem.add_runtime_dependency 'fastercsv'
gem.add_runtime_dependency 'tzinfo'
gem.add_runtime_dependency 'thin'
gem.add_runtime_dependency 'curb'
gem.add_runtime_dependency 'daemons'
gem.add_runtime_dependency 'json'
gem.add_runtime_dependency 'tire'
#gem.add_runtime_dependency 'rpam'
gem.add_runtime_dependency 'net-ldap'

gem.add_development_dependency 'rake'
gem.add_development_dependency 'rspec'
gem.add_development_dependency 'rspec-mocks'

end
