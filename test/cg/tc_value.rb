# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Value class and
#			its subclasses.

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

class ValueTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)

		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end

	def test_array_values
		fun = @mod.functions.add('array_function_tester', RLTK::CG::NativeIntType,
		                         [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|

			blocks.append do
				ptr = alloca(RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2))

				array = load(ptr)
				array = insert_value(array, fun.params[0], 0)
				array = insert_value(array, fun.params[1], 1)

				ret(add(extract_value(array, 0), extract_value(array, 1)))
			end
		end

		assert_equal(5, @jit.run_function(fun, 2, 3).to_i)
	end

	def test_constant_array_from_array
		array = RLTK::CG::ConstantArray.new(RLTK::CG::NativeIntType, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1)])

		assert_instance_of(RLTK::CG::ConstantArray, array)
		assert_equal(2, array.length)
	end

	def test_constant_array_from_size
		array = RLTK::CG::ConstantArray.new(RLTK::CG::NativeIntType, 2) { |i| RLTK::CG::NativeInt.new(i) }

		assert_instance_of(RLTK::CG::ConstantArray, array)
		assert_equal(2, array.length)
	end

	def test_constant_vector_elements
		fun = @mod.functions.add('constant_vector_elements_tester', RLTK::CG::NativeIntType,
		                         [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|

			blocks.append do
				ptr = alloca(RLTK::CG::VectorType.new(RLTK::CG::NativeIntType, 2))

				vector = load(ptr)
				vector = insert_element(vector, fun.params[0], RLTK::CG::NativeInt.new(0))
				vector = insert_element(vector, fun.params[1], RLTK::CG::NativeInt.new(1))

				ret(add(extract_element(vector, RLTK::CG::NativeInt.new(0)), extract_element(vector, RLTK::CG::NativeInt.new(1))))
			end
		end

		assert_equal(5, @jit.run_function(fun, 2, 3).to_i)
	end

	def test_constant_vector_from_array
		vector = RLTK::CG::ConstantVector.new([RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1)])

		assert_instance_of(RLTK::CG::ConstantVector, vector)
		assert_equal(2, vector.size)
	end

	def test_constant_vector_from_size
		vector = RLTK::CG::ConstantVector.new(2) { |i| RLTK::CG::NativeInt.new(i) }

		assert_instance_of(RLTK::CG::ConstantVector, vector)
		assert_equal(2, vector.size)
	end

	def test_constant_vector_shuffle
		fun = @mod.functions.add('constant_vector_shuffle_tester', RLTK::CG::NativeIntType, Array.new(4, RLTK::CG::NativeIntType)) do |fun|
			blocks.append do
				vec_type = RLTK::CG::VectorType.new(RLTK::CG::NativeIntType, 2)

				v0 = load(alloca(vec_type))
				v0 = insert_element(v0, fun.params[0], RLTK::CG::NativeInt.new(0))
				v0 = insert_element(v0, fun.params[1], RLTK::CG::NativeInt.new(1))

				v1 = load(alloca(vec_type))
				v1 = insert_element(v1, fun.params[2], RLTK::CG::NativeInt.new(0))
				v1 = insert_element(v1, fun.params[3], RLTK::CG::NativeInt.new(1))

				v2 = shuffle_vector(v0, v1, RLTK::CG::ConstantVector.new([RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(3)]))

				ret(add(extract_element(v2, RLTK::CG::NativeInt.new(0)), extract_element(v2, RLTK::CG::NativeInt.new(1))))
			end
		end

		assert_equal(5, @jit.run_function(fun, 1, 2, 3, 4).to_i)
	end

	def test_constant_struct_from_size_packed
		struct = RLTK::CG::ConstantStruct.new(2, true) { |i| RLTK::CG::NativeInt.new(i) }

		assert_instance_of(RLTK::CG::ConstantStruct, struct)
		assert_equal(2, struct.operands.size)
	end

	def test_constant_struct_from_size_unpacked
		struct = RLTK::CG::ConstantStruct.new(2, false) { |i| RLTK::CG::NativeInt.new(i) }

		assert_instance_of(RLTK::CG::ConstantStruct, struct)
		assert_equal(2, struct.operands.size)
	end

	def test_constant_struct_from_values_packed
		struct = RLTK::CG::ConstantStruct.new([RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1)], true)

		assert_instance_of(RLTK::CG::ConstantStruct, struct)
		assert_equal(2, struct.operands.size)
	end

	def test_constant_struct_from_values_unpacked
		struct = RLTK::CG::ConstantStruct.new([RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1)], false)

		assert_instance_of(RLTK::CG::ConstantStruct, struct)
		assert_equal(2, struct.operands.size)
	end

	def test_equality
		v0 = RLTK::CG::NativeInt.new(0)
		v1 = RLTK::CG::NativeInt.new(1)
		v2 = RLTK::CG::NativeInt.new(v0.ptr)

		assert_equal(v0, v2)
		refute_equal(v0, v1)
	end
end
