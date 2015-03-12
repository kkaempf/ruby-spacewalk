# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'spacewalk/version'

Gem::Specification.new do |s|
  s.name        = 'spacewalk'
  s.version     = Spacewalk::VERSION

  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Klaus Kämpf']
  s.email       = ['kkaempf@suse.de']
  s.homepage    = 'https://github.com/kkaempf/ruby-spacewalk'
  s.summary     = %q{A pure-Ruby implementation of the Spacewalk client side}
  s.description = %q{Can be used for testing or to attach 'foreign'
systems}

  s.rubyforge_project = 'spacewalk'

  s.add_development_dependency('rake')
  s.add_development_dependency('bundler')

  s.files         = `git ls-files`.split("\n")
  s.files.reject! { |fn| fn == '.gitignore' }
  s.extra_rdoc_files    = Dir['README*', 'TODO*', 'CHANGELOG*', 'LICENSE']
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ['lib']
end
