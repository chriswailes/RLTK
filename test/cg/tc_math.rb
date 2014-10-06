# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for various math instructions.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/execution_engine'
require 'rltk/cg/type'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

class MathTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)

		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end

	def test_integer_binary_operations
		int_binop_assert(:add,   3, 2,  3 + 2)
		int_binop_assert(:sub,   3, 2,  3 - 2)
		int_binop_assert(:mul,   3, 2,  3 * 2)
		int_binop_assert(:udiv, 10, 2, 10 / 2)
		int_binop_assert(:sdiv, 10, 2, 10 / 2)
		int_binop_assert(:urem, 10, 3, 10 % 3)
		int_binop_assert(:srem, 10, 3, 10 % 3)
	end

	def test_integer_bitwise_binary_operations
		int_binop_assert(:shl,   2, 3,  2 << 3)
		int_binop_assert(:lshr, 16, 3, 16 >> 3)
		int_binop_assert(:ashr, 16, 3, 16 >> 3)
		int_binop_assert(:and,   2, 1,  2 & 1)
		int_binop_assert(:or,    2, 1,  2 | 1)
		int_binop_assert(:xor,   3, 2,  3 ^ 2)
	end

	def test_float_binary_operations
		float_binop_assert(:fadd, 3.1, 2.2, 3.1 + 2.2)
		float_binop_assert(:fsub, 3.1, 2.2, 3.1 - 2.2)
		float_binop_assert(:fmul, 3.1, 2.2, 3.1 * 2.2)
		float_binop_assert(:fdiv, 3.1, 2.2, 3.1 / 2.2)
		float_binop_assert(:frem, 3.1, 2.2, 3.1 % 2.2)
	end

	def test_simple_math_fun
		fun = @mod.functions.add('simple_math_tester', RLTK::CG::FloatType, [RLTK::CG::FloatType]) do |fun|
			blocks.append do
				ret(fadd(fun.params[0], RLTK::CG::Float.new(1.0)))
			end
		end

		assert_equal(6.0, @jit.run_function(fun, 5.0).to_f)
	end

	##################
	# Helper Methods #
	##################

	def float_binop_assert(op, operand0, operand1, expected)
		assert_in_delta(expected, run_binop(op, RLTK::CG::Float.new(operand0), RLTK::CG::Float.new(operand1), RLTK::CG::FloatType).to_f, 0.001)
	end

	def int_binop_assert(op, operand0, operand1, expected)
		assert_equal(expected, run_binop(op, RLTK::CG::NativeInt.new(operand0), RLTK::CG::NativeInt.new(operand1), RLTK::CG::NativeIntType).to_i)
	end

	def run_binop(op, operand0, operand1, ret_type)
		fun = @mod.functions.add(op.to_s + '_tester', ret_type, []) do
			blocks.append { ret(self.send(op, operand0, operand1)) }
		end

		@jit.run_function(fun)
	end
end
