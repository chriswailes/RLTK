# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This is RLTK's Rakefile.

##############
# Rake Tasks #
##############

# Gems
require 'rake/testtask'
require 'bundler'

require File.expand_path("../lib/rltk/version", __FILE__)

begin
	require 'yard'

	YARD::Rake::YardocTask.new do |t|
		yardlib = File.join(File.dirname(__FILE__), 'yardlib/rltk.rb')
		
		t.options	= [
			'-e',		yardlib,
			'--title',	'The Ruby Language Toolkit',
			'-m',		'markdown',
			'-M',		'redcarpet',
			'-c',		'.yardoc/cache',
			'--private'
		]
		
		
		t.files	= Dir['lib/**/*.rb'] + ['-'] + Dir['examples/kazoo/**/*.md'].sort
	end
	
rescue LoadError
	warn 'Yard is not installed. `gem install yard` to build documentation.'
end

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.loader = :testrb
	t.test_files = FileList['test/ts_rltk.rb']
end

if RUBY_VERSION[0..2] == '1.8'
	begin
		require 'rcov/rcovtask'
		
		Rcov::RcovTask.new do |t|
			t.libs      << 'test'
			t.rcov_opts << '--exclude gems,ruby'
			
			t.test_files = FileList['test/tc_*.rb']
		end
		
	rescue LoadError
		warn 'Rcov not installed.'
	end
end

# Bundler tasks.
Bundler::GemHelper.install_tasks

# Rubygems Taks
begin
	require 'rubygems/tasks'
	
	Gem::Tasks.new do |t|
		t.console.command = 'pry'
	end
	
rescue LoadError
	'rubygems-tasks not installed.'
end

desc 'Generate the bindings for LLVM.'
task :gen_bindings do
	require 'ffi_gen'
	
	# Generate the standard LLVM bindings.
	
	blacklist = [
		'LLVMGetMDNodeOperand',
		'LLVMGetMDNodeNumOperands',
		'LLVMInitializeAllTargetInfos',
		'LLVMInitializeAllTargets',
		'LLVMInitializeNativeTarget'
	]
	
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
		'llvm-c/Object.h',
		'llvm-c/Target.h',
		
		'llvm-c/Transforms/IPO.h',
		'llvm-c/Transforms/Scalar.h'
	]
	
	FFIGen.generate(
		:module_name	=> 'RLTK::CG::Bindings',
		:ffi_lib		=> "LLVM-#{RLTK::LLVM_TARGET_VERSION}",
		:headers		=> headers,
		:cflags		=> `llvm-config --cflags`.split,
		:prefixes		=> ['LLVM'],
		:blacklist	=> blacklist + deprecated,
		:output		=> 'lib/rltk/cg/generated_bindings.rb'
	)
	
	# Generate the extended LLVM bindings.
	
	headers = [
		'llvm-ecb.h',
		
		'llvm-ecb/asm.h',
		'llvm-ecb/module.h',
		'llvm-ecb/support.h',
		
		'llvm-ecb/value.h',
		'llvm-ecb/target.h'

		# This causes value.h to not be included.
		#'llvm-ecb/target.h',
		#'llvm-ecb/value.h'
	]
	
	begin
		FFIGen.generate(
			:module_name	=> 'RLTK::CG::Bindings',
			:ffi_lib		=> "LLVM-ECB-#{RLTK::LLVM_TARGET_VERSION}",
			:headers		=> headers,
			:cflags		=> `llvm-config --cflags`.split,
			:prefixes		=> ['LLVM'],
			:output		=> 'lib/rltk/cg/generated_extended_bindings.rb'
		)
	rescue
	end
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

