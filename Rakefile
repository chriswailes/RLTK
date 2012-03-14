# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

require 'rake/testtask'
require 'bundler'

require File.expand_path("../lib/rltk/version", __FILE__)

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

task :check_bindings, :verbose do |t, args|
	(args = args.to_hash)[:verbose] = (args[:verbose] == 'true')
	
	require 'lib/rltk/cg/bindings'
	
	# Check for objdump.
	if not (bin = `which objdump`.chomp)[0,1] == '/'
		warn 'objdump binary not found.'
		return
	end
	
	# Locate the LLVM shared library.
	lib_path = nil
	
	paths  = ENV['LD_LIBRARY_PATH'].split(/:/).uniq
	paths << '/usr/lib/'
	paths << '/usr/lib64/'
	
	paths.each do |path|
		test_path = File.join(path, "libLLVM-#{RLTK::LLVM_TARGET_VERSION}.so")
		if File.exists?(test_path)
			lib_path = test_path
		end
	end
	
	if not lib_path
		puts "libLLVM-#{RLTK::LLVM_TARGET_VERSION}.so not found."
		return
	end
	
	# Grab libLLVM symbols.
	lines = `#{bin} -t #{lib_path}`
	
	lsyms = lines.map do |l|
		md = l.match(/\s(LLVM\w+)/)
		if md then md[1] else nil end
	end.compact.uniq
	
	# Grab libLLVM-EB symbols.
	lib_path = "ext/libLLVM-ECB-#{RLTK::LLVM_TARGET_VERSION}.so"
	
	if not File.exists?(lib_path)
		puts 'Extending Bindings shared library not present.'
		return
	end
	
	lines = `#{bin} -t #{lib_path}`
	
	lsyms |= lsyms = lines.map do |l|
		md = l.match(/\s(LLVM\w+)/)
		if md then md[1] else nil end
	end.compact.uniq
	
	# Defined symbols.
	dsyms = Symbol.all_symbols.map do |sym|
		sym = sym.to_s
		if sym.match(/^LLVM[a-zA-Z]+/) then sym else nil end
	end.compact
	
	# Sort the symbols.
	bound	= Array.new
	unbound	= Array.new
	unbinds	= Array.new

	lsyms.each do |sym|
		if dsyms.include?(sym) then bound else unbound end << sym
	end
	
	dsyms.each do |sym|
		if not lsyms.include?(sym) then unbinds << sym end
	end
	
	puts "Bound Functions: #{bound.length}"
	puts "Unbound Functions: #{unbound.length}"
	puts "Bad Bindings: #{unbinds.length}"
	puts "Completeness: #{((bound.length / lsyms.length.to_f) * 100).to_i}%"
	
	if args[:verbose]
		puts() if unbound.length > 0 and unbinds.length > 0
		
		if unbound.length > 0
			puts 'Unbound Functions:'
			unbound.sort.each {|sym| puts sym}
			puts
		end
		
		if unbinds.length > 0
			puts 'Bad Bindings:'
			unbinds.sort.each {|sym| puts sym}
		end
	end
end
