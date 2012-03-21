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

Rake::TestTask.new do |t|
	t.libs << 'test'
	t.loader = :testrb
	t.test_files = FileList['test/ts_rltk.rb']
end

if RUBY_VERSION.match(/1\.8/)
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

desc 'Generate the bindings for LLVM'
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
		:ruby_module => 'RLTK::CG::Bindings',
		:ffi_lib     => "LLVM-#{RLTK::LLVM_TARGET_VERSION}",
		:headers     => headers,
		:cflags      => `llvm-config --cflags`.split,
		:prefixes    => ['LLVM'],
		:blacklist   => blacklist + deprecated,
		:output      => 'lib/rltk/cg/generated_bindings.rb'
	)
	
	# Generate the extended LLVM bindings.
	
	headers = [
		'llvm-ecb.h',
		
		'llvm-ecb/support.h'
	]
	
	begin
		FFIGen.generate(
			:ruby_module => 'RLTK::CG::Bindings',
			:ffi_lib     => "LLVM-ECB-#{RLTK::LLVM_TARGET_VERSION}",
			:headers     => headers,
			:cflags      => `llvm-config --cflags`.split,
			:prefixes    => ['LLVM'],
			:output      => 'lib/rltk/cg/generated_extended_bindings.rb'
		)
	rescue
	end
end

desc 'Find LLVM bindings with a substring.'
task :find_bind, :part do |t, args|
	
	# Get the task argument.
	part = args[:part]
	
	# Require the Bindings module.
	require 'rltk/cg/bindings'
	
	syms =
	Symbol.all_symbols.select do |sym|
		sym = sym.to_s.downcase
		
		sym[0..3] == 'llvm' and sym.include?(part)
	end
	
	puts
	if not syms.empty?
		puts 'Matching bindings:'
		syms.each { |sym| puts "\t#{sym}" }
	
	else
		puts 'No matching bindings.'
	end
	puts
end

