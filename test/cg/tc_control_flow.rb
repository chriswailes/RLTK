# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for control flow instructions.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/execution_engine'
require 'rltk/cg/module'
require 'rltk/cg/function'
require 'rltk/cg/type'

class ControlFlowTester < Test::Unit::TestCase
	def setup
		RLTK::CG::LLVM.init(:X86)
		
		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end
	
	def test_select
		fun = @mod.functions.add('select_tester', RLTK::CG::Int1Type, [RLTK::CG::NativeIntType])
		fun.blocks.append.build do
			ret(select(fun.params[0], RLTK::CG::Int1.new(0), RLTK::CG::Int1.new(1)))
		end
		
		assert_equal(0, @jit.run_function(fun, 1).to_i(false))
		assert_equal(1, @jit.run_function(fun, 0).to_i(false))
	end
end
