# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for the RLTK::CG::Module class.

############
# Requires #
############

# Standard Library
require 'tempfile'
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
		
		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
		
		@mod.functions.add('test_int_function', RLTK::CG::NativeIntType, []) do
			blocks.append do
				ret RLTK::CG::NativeInt.new(1)
			end
		end
	end
	
	def test_bitcode
		Tempfile.open('bitcode') do |tmp|
			assert(@mod.write_bitcode(tmp))
			
			new_mod = RLTK::CG::Module.read_bitcode(tmp.path)
			new_jit = RLTK::CG::JITCompiler.new(new_mod)
			
			assert_equal(1, new_jit.run_function(new_mod.functions['test_int_function']).to_i)
		end
	end
	
	def test_simple_int_fun
		assert_equal(1, @jit.run_function(@mod.functions['test_int_function']).to_i)
	end
	
	def test_simple_float_fun
		fun = @mod.functions.add('test_float_function', RLTK::CG::FloatType, []) do
			blocks.append do
				ret RLTK::CG::Float.new(1.5)
			end
		end
		
		assert_equal(1.5, @jit.run_function(fun).to_f(RLTK::CG::FloatType))
	end
	
	def test_simple_double_fun
		fun = @mod.functions.add('test_double_function', RLTK::CG::DoubleType, []) do
			blocks.append do
				ret RLTK::CG::Double.new(1.6)
			end
		end
		
		assert_equal(1.6, @jit.run_function(fun).to_f(RLTK::CG::DoubleType))
	end
	
	def test_external_fun
		fun = @mod.functions.add(:sin, RLTK::CG::DoubleType, [RLTK::CG::DoubleType])
		res = @jit.run_function(fun, RLTK::CG::GenericValue.new(1.0, RLTK::CG::DoubleType)).to_f(RLTK::CG::DoubleType)
		
		assert_in_delta(Math.sin(1.0), res, 1e-10)
	end
end
