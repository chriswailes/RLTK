# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for rltk/cg/llvm.rb file.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/execution_engine'
require 'rltk/cg/type'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

class ModuleTester < Test::Unit::TestCase
	def setup
		RLTK::CG::LLVM.init(:X86)
	end
	
	def test_simple_module
		mod = RLTK::CG::Module.new('Testing Module')
		jit = RLTK::CG::JITCompiler.new(mod)
		fun = mod.functions.add('test_function', RLTK::CG::NativeIntType, [])
		
		fun.blocks.append.build do
			ret RLTK::CG::NativeInt.new(1)
		end
		
		assert_nil(mod.verify)
		assert_equal(1, jit.run_function(fun).to_i)
	end
end
