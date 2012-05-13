# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Type class and
#			its subclasses.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/cg/type'

class TypeTester < Test::Unit::TestCase
	def setup
		@pointee = RLTK::CG::NativeIntType.instance
		@pointer = RLTK::CG::PointerType.new(@pointee)
	end
	
	def test_element_type
		assert_equal(@pointee, @pointer.element_type)
	end
	
	def test_equality
		assert_equal(RLTK::CG::NativeIntType, RLTK::CG::NativeIntType)
		assert_not_equal(RLTK::CG::NativeIntType, RLTK::CG::FloatType)
		
		at0 = RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2)
		at1 = RLTK::CG::ArrayType.new(RLTK::CG::NativeIntType, 2)
		at2 = RLTK::CG::ArrayType.new(RLTK::CG::FloatType, 2)
		
		assert_equal(at0, at1)
		assert_not_equal(at0, at2)
	end
	
	def test_kind
		assert_equal(:pointer, @pointer.kind)
		assert_equal(:integer, @pointee.kind)
	end
end
