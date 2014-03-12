# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::Token class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/token'

#######################
# Classes and Modules #
#######################

class TokenTester < Minitest::Test
	def test_equal
		t0 = RLTK::Token.new(:FOO, 0)
		t1 = RLTK::Token.new(:FOO, 0)
		t2 = RLTK::Token.new(:FOO, 1)
		t3 = RLTK::Token.new(:BAR, 0)
		t4 = RLTK::Token.new(:BAR, 1)
		
		assert_equal(t0, t1)
		
		assert_not_equal(t0, t2)
		assert_not_equal(t0, t3)
		assert_not_equal(t0, t4)
	end
end
