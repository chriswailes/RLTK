# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file adds some autoload features for the RLTK code
#			generation.

#######################
# Classes and Modules #
#######################

module RLTK
	# This module contains classes and methods for code generation.  Code
	# generation functionality is provided by bindings to
	# [LLVM](http://llvm.org).
	module CG
		autoload :BasicBlock,      'rltk/cg/basic_block'
		autoload :Bindings,        'rltk/cg/bindings'
		autoload :Builder,         'rltk/cg/builder'
		autoload :Context,         'rltk/cg/context'
		autoload :ExecutionEngine, 'rltk/cg/execution_engine'
		autoload :Function,        'rltk/cg/function'
		autoload :GenericValue,    'rltk/cg/generic_value'
		autoload :Instruction,     'rltk/cg/instruction'
		autoload :LLVM,            'rltk/cg/llvm'
		autoload :MemoryBuffer,    'rltk/cg/memory_buffer'
		autoload :Module,          'rltk/cg/module'
		autoload :PassManager,     'rltk/cg/pass_manager'
		autoload :Support,         'rltk/cg/support'
		autoload :Type,            'rltk/cg/type'
		autoload :Value,           'rltk/cg/value'
	end
end
