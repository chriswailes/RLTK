# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

require 'rake/testtask'
require 'bundler'

begin
	require 'rdoc/task'
	
	RDoc::Task.new do |t|
		t.title		= 'The Ruby Language Toolkit'
		t.main		= 'README'
		t.rdoc_dir	= 'doc'
	
		t.rdoc_files.include('README', 'lib/*.rb', 'lib/rltk/*.rb', 'lib/rltk/**/*.rb')
	end

rescue LoadError
	warn 'RDoc is not installed.'
end

begin
	require 'rcov/rcovtask'
	
	Rcov::RcovTask.new do |t|
		t.libs		<< 'test'
		t.rcov_opts	<< '--exclude gems,ruby'
		t.test_files	= FileList['test/tc_*.rb']
	end
	
rescue LoadError
	warn 'Rcov not installed.'
end

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.loader = :testrb
	t.test_files = FileList['test/ts_rltk.rb']
end

Bundler::GemHelper.install_tasks
