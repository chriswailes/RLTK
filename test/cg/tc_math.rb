# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for various math instructions.

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

#######################
# Classes and Modules #
#######################

class MathTester < Test::Unit::TestCase	
	def setup
		RLTK::CG::LLVM.init(:X86)
		
		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end
	
	def test_fadd_fun
		fun = @mod.functions.add('test_fadd_function', RLTK::CG::FloatType, [RLTK::CG::FloatType]) do |fun|
			blocks.append do
				ret(fadd(fun.params[0], RLTK::CG::Float.new(1.0)))
			end
		end
		
		assert_equal(6.0, @jit.run_function(fun, 5.0).to_f)
	end
end
