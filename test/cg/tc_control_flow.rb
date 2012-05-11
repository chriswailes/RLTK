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
	
	def test_phi
		fun = @mod.functions.add('phi_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType]) do |fun|
			entry	= blocks.append('entry')
			block0	= blocks.append('block0')
			block1	= blocks.append('block1')
			exit		= blocks.append('exit')
		
			entry.build do
				cond(icmp(:eq, fun.params[0], RLTK::CG::NativeInt.new(0)), block0, block1)
			end
		
			result0 =
			block0.build do
				returning(add(fun.params[0], RLTK::CG::NativeInt.new(1))) { br(exit) }
			end
		
			result1 =
			block1.build do
				returning(sub(fun.params[0], RLTK::CG::NativeInt.new(1))) { br(exit) }
			end
		
			exit.build do
				ret(phi(RLTK::CG::NativeIntType, {block0 => result0, block1 => result1}))
			end
		end
		
		assert_equal(1, @jit.run_function(fun, 0).to_i)
		assert_equal(0, @jit.run_function(fun, 1).to_i)
	end
	
	def test_select
		fun = @mod.functions.add('select_tester', RLTK::CG::Int1Type, [RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				ret(select(fun.params[0], RLTK::CG::Int1.new(0), RLTK::CG::Int1.new(1)))
			end
		end
		
		assert_equal(0, @jit.run_function(fun, 1).to_i(false))
		assert_equal(1, @jit.run_function(fun, 0).to_i(false))
	end
end
