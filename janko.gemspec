# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'janko/version'

Gem::Specification.new do |spec|
    spec.name = "janko"
    spec.version = Janko::VERSION
    spec.authors = ["Don Werve"]
    spec.email = ["don@werve.net"]
    spec.summary = %q{High-performance import, merge, and upsert for PostgreSQL.}
    spec.description = %q{Because sometimes you just need to feed PostgreSQL a lot of data.}
    spec.homepage = "https://github.com/matadon/janko"
    spec.license = "Apache-2.0"
    spec.files = `git ls-files -z`.split("\x0")
    spec.executables = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]
    spec.add_runtime_dependency 'pg', '~> 0.17', '> 0.17'
    spec.add_runtime_dependency 'agrippa', '~> 0.0.1', '>= 0.0.1'
    spec.add_development_dependency "bundler", "~> 1.6"
    spec.add_development_dependency "rake", "~> 10.0"
    spec.add_development_dependency 'rspec', '~> 3.0', '>= 3.0.0'
    spec.add_development_dependency 'guard', '~> 2.8'
    spec.add_development_dependency 'guard-rspec', '~> 4.3'
    spec.add_development_dependency 'ruby_gntp', '~> 0'
    spec.add_development_dependency 'simplecov', '~> 0'
    spec.add_development_dependency 'pry', '~> 0'
    spec.add_development_dependency 'activerecord', '~> 4.1', '> 4.1'
end
