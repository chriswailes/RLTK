# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Instruction
#			class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/instruction'

class InstructionTester < Test::Unit::TestCase
	def setup
		RLTK::CG::LLVM.init(:X86)
		
		@mod = RLTK::CG::Module.new('Testing Module')
	end
	
	def test_instruction
		fun = @mod.functions.add('test_instruction', RLTK::CG::DoubleType, [RLTK::CG::DoubleType]) do |fun|
			blocks.append do
				ret(fadd(fun.params[0], RLTK::CG::Double.new(3.0)))
			end
		end
		
		entry = fun.blocks.entry
		
		inst0 = entry.instructions.first
		inst1 = entry.instructions.last
		
		assert_kind_of(RLTK::CG::Instruction, inst0)
		assert_kind_of(RLTK::CG::Instruction, inst1)
		
		assert_equal(inst1, inst0.next)
		assert_equal(inst0, inst1.previous)
		
		assert_equal(entry, inst0.parent)
		assert_equal(entry, inst1.parent)
	end
end
