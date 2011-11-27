# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

require 'rake/testtask'
require 'rubygems/package_task'
require 'rdoc/task'

RDoc::Task.new do |t|
	t.title		= 'The Ruby Language Toolkit'
	t.main		= 'README'
	t.rdoc_dir	= 'doc'
	
	t.rdoc_files.include('README', 'lib/*.rb', 'lib/rltk/*.rb', 'lib/rltk/**/*.rb')
end

#Rake::TestTask.new do |t|
#	t.libs << 'test'
#	t.test_files = FileList['test/ts_rltk.rb']
#end

# This workaround is here because the Rake::DSL module gets auto-loaded into
# the Object class, and therefor any object that defines conflicting methods
# get over-ridden.
task :test do
	exec "ruby -C \"test\" -e \"require 'ts_rltk.rb'\""
end

def spec
	Gem::Specification.new do |s|
		s.platform = Gem::Platform::RUBY
		
		s.name		= 'rltk'
		s.version		= '1.0.1'
		s.summary		= 'The Ruby Language Toolkit'
		s.description	=
			'The Ruby Language Toolkit provides classes for creating' +
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
		s.email		= 'chris.wailes@gmail.com'
		s.homepage	= 'http://launchpad.net/rltk'
		s.license		= 'University of Illinois/NCSA Open Source License'
		
		s.test_files	= Dir.glob('test/tc_*.rb')
	end
end

Gem::PackageTask.new(spec) do |t|
	t.need_tar = true
end
