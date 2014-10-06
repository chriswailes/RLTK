# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for the RLTK::CG::Module class.

############
# Requires #
############

# Standard Library
require 'tempfile'

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

class ModuleTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)

		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)

		@mod.functions.add('int_function_tester', RLTK::CG::NativeIntType, []) do
			blocks.append { ret RLTK::CG::NativeInt.new(1) }
		end
	end

	def test_bitcode
		Tempfile.open('bitcode') do |tmp|
			assert(@mod.write_bitcode(tmp))

			new_mod = RLTK::CG::Module.read_bitcode(tmp.path)
			new_jit = RLTK::CG::JITCompiler.new(new_mod)

			assert_equal(1, new_jit.run_function(new_mod.functions['int_function_tester']).to_i)
		end
	end

	def test_equality
		mod0 = RLTK::CG::Module.new('foo')
		mod1 = RLTK::CG::Module.new('bar')
		mod2 = RLTK::CG::Module.new(mod0.ptr)

		assert_equal(mod0, mod2)
		refute_equal(mod0, mod1)
	end

	def test_external_fun
		fun = @mod.functions.add(:sin, RLTK::CG::DoubleType, [RLTK::CG::DoubleType])
		res = @jit.run_function(fun, RLTK::CG::GenericValue.new(1.0, RLTK::CG::DoubleType)).to_f(RLTK::CG::DoubleType)

		assert_in_delta(Math.sin(1.0), res, 1e-10)
	end

	def test_simple_int_fun
		assert_equal(1, @jit.run_function(@mod.functions['int_function_tester']).to_i)
	end

	def test_simple_float_fun
		fun = @mod.functions.add('float_function_tester', RLTK::CG::FloatType, []) do
			blocks.append do
				ret RLTK::CG::Float.new(1.5)
			end
		end

		assert_equal(1.5, @jit.run_function(fun).to_f(RLTK::CG::FloatType))
	end

	def test_simple_double_fun
		fun = @mod.functions.add('double_function_tester', RLTK::CG::DoubleType, []) do
			blocks.append do
				ret RLTK::CG::Double.new(1.6)
			end
		end

		assert_equal(1.6, @jit.run_function(fun).to_f(RLTK::CG::DoubleType))
	end
end
