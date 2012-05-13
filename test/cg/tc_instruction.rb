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
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end
	
	def test_float_comparison
		fcmp_assert(:oeq, 1.0, 1.0, true )
		fcmp_assert(:one, 1.0, 1.0, false)
		fcmp_assert(:ogt, 2.0, 2.0, false)
		fcmp_assert(:oge, 2.0, 1.0, true )
		fcmp_assert(:olt, 1.0, 1.0, false)
		fcmp_assert(:ole, 1.0, 2.0, true )
		fcmp_assert(:ord, 1.0, 2.0, true )
		fcmp_assert(:ueq, 1.0, 1.0, true )
		fcmp_assert(:une, 1.0, 1.0, false)
		fcmp_assert(:ugt, 2.0, 2.0, false)
		fcmp_assert(:uge, 2.0, 1.0, true )
		fcmp_assert(:ult, 1.0, 1.0, false)
		fcmp_assert(:ule, 1.0, 2.0, true )
		fcmp_assert(:uno, 1.0, 2.0, false)
	end
	
	def test_instruction
		fun = @mod.functions.add('instruction_tester', RLTK::CG::DoubleType, [RLTK::CG::DoubleType]) do |fun|
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
	
	def test_integer_comparison
		icmp_assert(:eq,   1, 1, true,  true )
		icmp_assert(:ne,   1, 1, true,  false)
		icmp_assert(:ugt,  2, 2, false, false)
		icmp_assert(:uge,  2, 1, false, true )
		icmp_assert(:ult,  1, 1, false, false)
		icmp_assert(:ule,  1, 2, false, true )
		icmp_assert(:sgt, -2, 2, true,  false)
		icmp_assert(:sge, -2, 1, true,  false)
		icmp_assert(:slt, -1, 2, true,  true )
		icmp_assert(:sle, -1, 2, true,  true )
	end
	
	def test_array_memory_access
		fun = @mod.functions.add('array_memory_access_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				ptr = array_alloca(RLTK::CG::NativeIntType, RLTK::CG::NativeInt.new(2))
				
				store(fun.params[0], gep(ptr, [RLTK::CG::NativeInt.new(0)]))
				store(fun.params[1], gep(ptr, [RLTK::CG::NativeInt.new(1)]))
				
				ret(add(load(gep(ptr, [RLTK::CG::NativeInt.new(0)])), load(gep(ptr, [RLTK::CG::NativeInt.new(1)]))))
			end
		end
		
		assert_equal(3, @jit.run_function(fun, 1, 2).to_i)
	end
	
	def test_simple_memory_access
		fun = @mod.functions.add('simple_memory_access_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				p0 = alloca(RLTK::CG::NativeIntType)
				p1 = alloca(RLTK::CG::NativeIntType)
				
				store(fun.params[0], p0)
				store(fun.params[1], p1)
				
				ret(add(load(p0), load(p1)))
			end
		end
		
		assert_equal(3, @jit.run_function(fun, 1, 2).to_i)
	end
	
	##################
	# Helper Methods #
	##################
	
	def fcmp_assert(mode, operand0, operand1, expected)
		res = run_cmp(:fcmp, mode, RLTK::CG::Float.new(operand0), RLTK::CG::Float.new(operand1), RLTK::CG::Int1Type).to_i(false)
		assert_equal(expected.to_i, res)
	end
	
	def icmp_assert(mode, operand0, operand1, signed, expected)
		res = run_cmp(:icmp, mode, RLTK::CG::NativeInt.new(operand0, signed), RLTK::CG::NativeInt.new(operand1, signed), RLTK::CG::Int1Type).to_i(false)
		assert_equal(expected.to_i, res)
	end
	
	def run_cmp(op, mode, operand0, operand1, ret_type)
		fun = @mod.functions.add("#{op}_#{mode}_tester", ret_type, []) do
			blocks.append { ret(self.send(op, mode, operand0, operand1)) }
		end
		
		@jit.run_function(fun)
	end
end
