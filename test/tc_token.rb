# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::Token class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/token'

#######################
# Classes and Modules #
#######################

class TokenTester < Test::Unit::TestCase
	def test_equal
		t0 = Token.new(:FOO, 0)
		t1 = Token.new(:FOO, 0)
		t2 = Token.new(:FOO, 1)
		t3 = Token.new(:BAR, 0)
		t4 = Token.new(:BAR, 1)
		
		assert_equal(t0, t1)
		
		assert_not_equal(t0, t2)
		assert_not_equal(t0, t3)
		assert_not_equal(t0, t4)
	end
end
