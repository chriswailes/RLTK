# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Function class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/function'
require 'rltk/cg/type'

class FunctionTester < Minitest::Test
	def setup
		@mod = RLTK::CG::Module.new('Testing Module')
		@fun = @mod.functions.add('testing_function', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType])

		@fun.params[0].name = 'foo'
		@fun.params[1].name = 'bar'
	end

	def test_equality
		fun0 = @mod.functions.add('fun0', RLTK::CG::NativeIntType, [])
		fun1 = @mod.functions.add('fun0', RLTK::CG::FloatType, [])
		fun2 = RLTK::CG::Function.new(fun0.ptr)

		assert_equal(fun0, fun2)
		refute_equal(fun0, fun1)
	end

	def test_positive_index_in_range
		assert_equal('foo', @fun.params[0].name)
		assert_equal('bar', @fun.params[1].name)
	end

	def test_negative_index_in_range
		assert_equal('bar', @fun.params[-1].name)
		assert_equal('foo', @fun.params[-2].name)
	end

	def test_positive_index_out_of_range
		assert_nil(@fun.params[2])
	end

	def test_negative_index_out_of_range
		assert_nil(@fun.params[-3])
	end
end
