# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This is RLTK's Gem specification.

require File.expand_path("../lib/rltk/version", __FILE__)

Gem::Specification.new do |s|
	s.platform = Gem::Platform::RUBY
	
	s.name		= 'rltk'
	s.version		= RLTK::VERSION
	s.summary		= 'The Ruby Language Toolkit'
	s.description	=
		'The Ruby Language Toolkit provides classes for creating ' +
		'context-free grammars, lexers, parsers, and abstract syntax trees.'
	
	s.files = [
			'LICENSE',
			'AUTHORS',
			'README',
			'Rakefile',
			] +
			Dir.glob('lib/rltk/**/*.rb')
			
			
	s.require_path	= 'lib'
	
	s.author		= 'Chris Wailes'
	s.email		= 'chris.wailes+rltk@gmail.com'
	s.homepage	= 'http://github.com/chriswailes/RLTK'
	s.license		= 'University of Illinois/NCSA Open Source License'
	
	s.add_dependency('ffi', '>= 1.0.0')
	
	s.add_development_dependency('bundler')
	s.add_development_dependency('ffi_gen')
	s.add_development_dependency('rake')
	s.add_development_dependency('rcov')
	s.add_development_dependency('simplecov')
	s.add_development_dependency('yard')
	
	s.test_files	= Dir.glob('test/tc_*.rb') + Dir.glob('test/ts_*.rb')
end
