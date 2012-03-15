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

desc "Check the current bindings in RLTK against the LLVM and LLVM-ECB shared libraries"
task :check_bindings, :verbose do |_, args|
	(args = args.to_hash)[:verbose] = (args[:verbose] == 'true')
	
	# Require the file that contains all of the bindings.
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
	paths << '/usr/local/lib'
	paths << '/usr/local/lib64'
	
	paths.each do |path|
		test_path = File.join(path, "libLLVM-#{RLTK::LLVM_TARGET_VERSION}.so")
		lib_path  = test_path if File.exists?(test_path)
	end
	
	if not lib_path
		warn "libLLVM-#{RLTK::LLVM_TARGET_VERSION}.so not found."
		next
	end
	
	# Grab libLLVM symbols.
	lines = `#{bin} -t #{lib_path}`
	
	libsyms = lines.map do |l|
		md = l.match(/\s(LLVM\w+)/)
		if md then md[1] else nil end
	end.compact.uniq
	
	# Grab libLLVM-ECB symbols.
	lib_path = nil
	
	paths.each do |path|
		test_path = File.join(path, "libLLVM-ECB-#{RLTK::LLVM_TARGET_VERSION}.so")
		lib_path  = test_path if File.exists?(test_path)
	end
	
	if lib_path
		lines = `#{bin} -t #{lib_path}`
		
		ecbsyms = lines.map do |l|
			md = l.match(/\s(LLVM\w+)/)
			if md then md[1] else nil end
		end.compact.uniq
		
	else
		ecbsyms = nil
		
		warn 'LLVM Extended C Bindings shared library not present.'
	end
	
	# Defined symbols.
	defsyms = Symbol.all_symbols.map do |sym|
		sym = sym.to_s
		if sym.match(/^LLVM[a-zA-Z]+/) then sym else nil end
	end.compact
	
	# Generate info for the default LLVM C bindings.
	bound   = Array.new
	unbound = Array.new
	
	libsyms.each do |sym|
		if defsyms.include?(sym) then bound else unbound end << sym
	end
	
	# Print information about the default LLVM C bindings.
	puts "Default LLVM C Bindings:"
	puts "Bound Functions: #{bound.length}"
	puts "Unbound Functions: #{unbound.length}"
	puts "Completeness: #{((bound.length / libsyms.length.to_f) * 100).to_i}%"
	puts
	
	if args[:verbose]
		puts 'Unbound function names:'
		
		unbound.sort.each {|sym| puts "\t#{sym}"}
		puts
	end
	
	if ecbsyms
		# Generate info for the extended LLVM C bindings.
		bound   = Array.new
		unbound = Array.new
		
		ecbsyms.each do |sym|
			if defsyms.include?(sym) then bound else unbound end << sym
		end
		
		# Print information about the extended LLVM C bindings.
		puts "Extended LLVM C Bindings:"
		puts "Bound Functions: #{bound.length}"
		puts "Unbound Functions: #{unbound.length}"
		puts "Completeness: #{((bound.length / ecbsyms.length.to_f) * 100).to_i}%"
		puts
		
		if args[:verbose]
			puts 'Unbound function names:'
		
			unbound.sort.each {|sym| puts "\t#{sym}"}
			puts
		end
		
		libsyms |= ecbsyms
	end
	
	# Print information about bad bindings.
	unbinds = Array.new
	defsyms.each do |sym|
		if not libsyms.include?(sym) then unbinds << sym end
	end
	
	puts "Bad Bindings: #{unbinds.length}"
	puts
	
	if args[:verbose]
		puts 'Bad binding names:'
		
		unbinds.sort.each {|sym| puts "\t#{sym}"}
		puts
	end
end

