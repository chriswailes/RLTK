# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Value class and
#			its subclasses.

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

class ValueTester < Test::Unit::TestCase
	def setup
		RLTK::CG::LLVM.init(:X86)
	end
	
	def test_array_values
		mod = RLTK::CG::Module.new('Testing Module')
		jit = RLTK::CG::JITCompiler.new(mod)
		
		fun = mod.functions.add('test_array_function', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				ptr = alloca(RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2))
			
				array = load(ptr)
				array = insert_value(array, fun.params[0], 0)
				array = insert_value(array, fun.params[1], 1)
			
				ret(add(extract_value(array, 0), extract_value(array, 1)))
			end
		end
		
		assert_equal(5, jit.run_function(fun, 2, 3).to_i)
	end
	
	def test_constant_array_from_array
		array = RLTK::CG::ConstantArray.new(RLTK::CG::NativeIntType, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1)])
		
		assert_equal(2, array.operands.size)
	end
	
	def test_constant_array_from_size
		array = RLTK::CG::ConstantArray.new(RLTK::CG::NativeIntType, 2) { |i| RLTK::CG::NativeInt.new(i) }
		
		assert_equal(2, array.operands.size)
	end
end
