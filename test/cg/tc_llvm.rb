# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for rltk/cg/llvm.rb file.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg/llvm'

#######################
# Classes and Modules #
#######################

class LLVMTester < Minitest::Test
	def test_init
		assert_raises(ArgumentError) { RLTK::CG::LLVM.init(:foo) }
	end
end
