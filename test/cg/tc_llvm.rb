# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for rltk/cg/llvm.rb file.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg/llvm'

#######################
# Classes and Modules #
#######################

class LLVMTester < Test::Unit::TestCase
	def test_init
		assert_raise(RuntimeError)	{ RLTK::CG::LLVM.init(:foo) }
		assert_nothing_raised		{ RLTK::CG::LLVM.init(:X86) }
	end
	
	def test_version
		assert_equal(RLTK::LLVM_TARGET_VERSION, RLTK::CG::LLVM.version)
	end
end
