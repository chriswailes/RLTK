# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

# Gems
require 'filigree/request_file'

# RLTK
require File.expand_path("../lib/rltk/version", __FILE__)

###########
# Bundler #
###########

request_file('bundler', 'Bundler is not installed.') do
	Bundler::GemHelper.install_tasks
end

########
# Flay #
########

request_file('flay', 'Flay is not installed.') do
	desc 'Analyze code for similarities with Flay'
	task :flay do
		flay = Flay.new
		flay.process(*Dir['lib/**/*.rb'])
		flay.report
	end
end

########
# Flog #
########

request_file('flog_cli', 'Flog is not installed.') do
	desc 'Analyze code complexity with Flog'
	task :flog do
		whip = FlogCLI.new
		whip.flog('lib')
		whip.report
	end
end

############
# MiniTest #
############

request_file('rake/testtask', 'Minitest is not installed.') do
	Rake::TestTask.new do |t|
		t.libs << 'test'
		t.test_files = FileList['test/ts_rltk.rb']
	end
end

#########
# Notes #
#########

request_file('rake/notes/rake_task', 'Rake-notes is not installed.')

########
# Reek #
########

request_file('reek/rake/task', 'Reek is not installed.') do
	Reek::Rake::Task.new do |t|
	  t.fail_on_error = false
	end
end

##################
# Rubygems Tasks #
##################

request_file('rubygems/tasks', 'Rubygems-tasks is not installed.') do
	Gem::Tasks.new do |t|
		t.console.command = 'pry'
	end
end

########
# YARD #
########

request_file('yard', 'Yard is not installed.') do
	YARD::Rake::YardocTask.new do |t|
		yardlib = File.join(File.dirname(__FILE__), 'yardlib/rltk.rb')
		
		t.options	= [
			'-e',       yardlib,
			'--title',  'The Ruby Language Toolkit',
			'-m',       'markdown',
			'-M',       'redcarpet',
			'--private'
		]
		
		t.files = Dir['lib/**/*.rb'] +
		          ['-'] +
		          Dir['examples/kazoo/**/*.md'].sort
	end
end

##############
# RLTK Tasks #
##############

desc 'Generate the bindings for LLVM.'
task :gen_bindings do
	require 'ffi_gen'
	
	# Generate the standard LLVM bindings.
	
	deprecated = [
		# BitReader.h
		'LLVMGetBitcodeModuleProviderInContext',
		'LLVMGetBitcodeModuleProvider',
		
		# BitWriter.h
		'LLVMWriteBitcodeToFileHandle',
		
		# Core.h
		'LLVMCreateFunctionPassManager',
		
		# ExectionEngine.h
		'LLVMCreateExecutionEngine',
		'LLVMCreateInterpreter',
		'LLVMCreateJITCompiler',
		'LLVMAddModuleProvider',
		'LLVMRemoveModuleProvider'
	]
	
	headers = [
		'llvm-c/Core.h',
		
		'llvm-c/Analysis.h',
		'llvm-c/BitReader.h',
		'llvm-c/BitWriter.h',
		'llvm-c/Disassembler.h',
		'llvm-c/ExecutionEngine.h',
		'llvm-c/Initialization.h',
		'llvm-c/IRReader.h',
		'llvm-c/Linker.h',
		'llvm-c/LinkTimeOptimizer.h',
		'llvm-c/Object.h',
		'llvm-c/Support.h',
		'llvm-c/Target.h',
		'llvm-c/TargetMachine.h',
		
		'llvm-c/Transforms/IPO.h',
		'llvm-c/Transforms/PassManagerBuilder.h',
		'llvm-c/Transforms/Scalar.h',
		'llvm-c/Transforms/Vectorize.h'
	]
	
	FFIGen.generate(
		module_name: 'RLTK::CG::Bindings',
		ffi_lib:     "LLVM-#{RLTK::LLVM_TARGET_VERSION}",
		headers:     headers,
		cflags:      `llvm-config --cflags`.split,
		prefixes:    ['LLVM'],
		blacklist:   deprecated,
		output:      'lib/rltk/cg/generated_bindings.rb'
	)
end

desc 'Find LLVM bindings with a regular expression.'
task :find_bind, :part do |t, args|
	
	# Get the task argument.
	part = Regexp.new(args[:part])
	
	# Require the Bindings module.
	require 'rltk/cg/bindings'
	
	syms =
	Symbol.all_symbols.select do |sym|
		sym = sym.to_s.downcase
		
		sym[0..3] == 'llvm' and sym[4..-1] =~ part
	end.sort
	
	puts
	if not syms.empty?
		puts "Matching bindings [#{syms.length}]:"
		syms.each { |sym| puts "\t#{sym}" }
	
	else
		puts 'No matching bindings.'
	end
	puts
end

