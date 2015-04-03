# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'file_db'

Gem::Specification.new do |spec|
  spec.name          = 'file_db'
  spec.version       = FileDB::VERSION
  spec.authors       = ['Rufus Post']
  spec.email         = ['rufuspost@gmail.com']
  spec.summary       = 'File DB.'
  spec.description   = 'File backed database with Etcd inspired API.'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'minitest-reporters'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'pry'
end
