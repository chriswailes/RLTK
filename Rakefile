# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

require 'rake/rdoctask'
require 'rake/testtask'

Rake::RDocTask.new do |rd|
	rd.main = 'README'
	rd.rdoc_dir = 'doc'
	rd.rdoc_files.include('README', 'lib/**/*.rb')
end

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.test_files = FileList['test/ts_rltk.rb']
	t.verbose = true
end

task :stats do
	puts `sloccount .`
end
