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
require 'rltk/cg/llvm'

puts "FOO"

require 'rltk/cg/module'

puts "BAR"

require 'rltk/cg/execution_engine'

puts "BAF"

#######################
# Classes and Modules #
#######################

class ModuleTester < Test::Unit::TestCase
	def setup
		RLTK::CG::LLVM.init(:X86)
	end
	
	def test_simple_module
		mod = RLTK::CG::Module.new('Testing Module')
		fun = mod.functions.add('Test Function', RLTK::CG::NativeIntType, [])
		
		fun.blocks.append.build do
			ret RLTK::CG::NativeInt.new(1)
		end
		
		engine = RLTK::CG::ExecutionEngine.new(mod)
		
		assert_equal(1, engine.run_function(fun).to_i)
	end
end
