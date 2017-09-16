# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2012/03/08
# Description: This is RLTK's Gem specification.

# Add the project to the load path.
lib_dir = File.expand_path("./lib/", File.dirname(__FILE__))
$LOAD_PATH << lib_dir unless $LOAD_PATH.include?(lib_dir)

require 'rltk/version'

Gem::Specification.new do |s|
	s.platform = Gem::Platform::RUBY

	s.name        = 'rltk'
	s.version     = RLTK::VERSION
	s.summary     = 'The Ruby Language Toolkit'
	s.description =
		'The Ruby Language Toolkit provides classes for creating ' +
		'context-free grammars, lexers, parsers, and abstract syntax trees.'

	s.files = [
		'LICENSE',
		'AUTHORS',
		'README.md',
		'Rakefile',
	] +
	Dir.glob('lib/**/*.rb')

	s.test_files = Dir['test/**/**.rb']

	s.require_path	= 'lib'

	s.author   = 'Chris Wailes'
	s.email    = 'chris.wailes+rltk@gmail.com'
	s.homepage = 'https://github.com/chriswailes/RLTK'
	s.license  = 'University of Illinois/NCSA Open Source License'

	s.required_ruby_version = '>= 2.4.0'

	################
	# Dependencies #
	################

	s.add_dependency('filigree', '>= 0.4.0')

	############################
	# Development Dependencies #
	############################

	s.add_development_dependency('bundler')
	s.add_development_dependency('flay')
	s.add_development_dependency('flog')
	s.add_development_dependency('minitest')
	s.add_development_dependency('rake')
	s.add_development_dependency('rake-notes')
	s.add_development_dependency('reek')
	s.add_development_dependency('simplecov')
	s.add_development_dependency('yard', '>= 0.8.1')
end
