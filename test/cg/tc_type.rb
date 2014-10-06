# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Type class and
#			its subclasses.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/type'

class TypeTester < Minitest::Test
	def setup
		@pointee = RLTK::CG::NativeIntType.instance
		@pointer = RLTK::CG::PointerType.new(@pointee)
	end

	def test_deferrent_element_type_stuct_type
		type = RLTK::CG::StructType.new([], 'test_struct')
		type.element_types = [RLTK::CG::NativeIntType, RLTK::CG::FloatType]

		assert_equal(2, type.element_types.size)
		assert_equal(RLTK::CG::NativeIntType.instance, type.element_types[0])
		assert_equal(RLTK::CG::FloatType.instance, type.element_types[1])

	end

	def test_element_type
		assert_equal(@pointee, @pointer.element_type)
	end

	def test_equality
		assert_equal(RLTK::CG::NativeIntType, RLTK::CG::NativeIntType)
		refute_equal(RLTK::CG::NativeIntType, RLTK::CG::FloatType)

		at0 = RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2)
		at1 = RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2)
		at2 = RLTK::CG::ArrayType.new(RLTK::CG::FloatType, 2)

		assert_equal(at0, at1)
		refute_equal(at0, at2)
	end

	def test_kind
		assert_equal(:pointer, @pointer.kind)
		assert_equal(:integer, @pointee.kind)
	end

	def test_named_struct_type
		type = RLTK::CG::StructType.new([RLTK::CG::NativeIntType, RLTK::CG::FloatType], 'test_struct')

		assert_instance_of(RLTK::CG::StructType, type)
		assert_equal('test_struct', type.name)
	end

	def test_simple_struct_type
		type = RLTK::CG::StructType.new([RLTK::CG::NativeIntType, RLTK::CG::FloatType])

		assert_instance_of(RLTK::CG::StructType, type)
		assert_equal(2, type.element_types.size)
		assert_equal(RLTK::CG::NativeIntType.instance, type.element_types[0])
		assert_equal(RLTK::CG::FloatType.instance, type.element_types[1])
	end
end
