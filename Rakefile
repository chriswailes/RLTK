# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

require 'rake/rdoctask'
require 'rake/testtask'

task :rdoc do
	`rdoc -w 5 -o doc -m README -t "The Ruby Language Toolkit" README lib/rltk/*.rb lib/rltk/**/*.rb`
end

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.test_files = FileList['test/ts_rltk.rb']
	t.verbose = true
end

task :stats do
	puts `sloccount .`
end
