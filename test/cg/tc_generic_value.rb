# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::GenericValue
#			class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/generic_value'

class GenericValueTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)
	end

	def test_integer
		assert_equal(2, RLTK::CG::GenericValue.new(2).to_i)
	end

	def test_float
		assert_in_delta(3.1415926, RLTK::CG::GenericValue.new(3.1415926).to_f, 1e-6)
	end

	def test_double
		assert_in_delta(3.1415926, RLTK::CG::GenericValue.new(3.1415926, RLTK::CG::DoubleType).to_f(RLTK::CG::DoubleType), 1e-6)
	end
end
