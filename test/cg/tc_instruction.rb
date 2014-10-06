# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for the RLTK::CG::Instruction
#			class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/instruction'

class InstructionTester < Minitest::Test
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
		fun = @mod.functions.add('array_memory_access_tester', RLTK::CG::NativeIntType,
		                         [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|

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
		fun = @mod.functions.add('simple_memory_access_tester', RLTK::CG::NativeIntType,
		                         [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|

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

	def test_struct_access
		fun = @mod.functions.add('struct_access_tester', RLTK::CG::FloatType, [RLTK::CG::NativeIntType, RLTK::CG::FloatType]) do |fun|
			blocks.append do
				st0 = RLTK::CG::StructType.new([RLTK::CG::NativeIntType, RLTK::CG::FloatType])
				st1 = RLTK::CG::StructType.new([RLTK::CG::FloatType, st0, RLTK::CG::NativeIntType])

				ptr = alloca(st1)

				store(fun.params[0], gep(ptr, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1), RLTK::CG::NativeInt.new(0)]))
				store(fun.params[1], gep(ptr, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1), RLTK::CG::NativeInt.new(1)]))

				addr0 = gep(ptr, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1), RLTK::CG::NativeInt.new(0)])
				addr1 = gep(ptr, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(1), RLTK::CG::NativeInt.new(1)])

				ret(fadd(ui2fp(load(addr0), RLTK::CG::FloatType), load(addr1)))
			end
		end

		assert_in_delta(5.3, @jit.run_function(fun, 2, 3.3).to_f, 0.001)
	end

	def test_struct_values
		fun = @mod.functions.add('struct_values_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				ptr = alloca(RLTK::CG::StructType.new([RLTK::CG::NativeIntType, RLTK::CG::NativeIntType]))

				struct = load(ptr)
				struct = insert_value(struct, fun.params[0], 0)
				struct = insert_value(struct, fun.params[1], 1)

				ret(add(extract_value(struct, 0), extract_value(struct, 1)))
			end
		end

		assert_equal(5, @jit.run_function(fun, 2, 3).to_i)
	end

	####################
	# Conversion Tests #
	####################

	def test_bitcast
		difftype_assert(:bitcast, RLTK::CG::Int8.new(255), RLTK::CG::Int8Type, :integer, -1)
	end

	def test_fp2ui
		difftype_assert(:fp2ui, RLTK::CG::Double.new(123.3), RLTK::CG::Int32Type, :integer, 123)
		difftype_assert(:fp2ui, RLTK::CG::Double.new(0.7),   RLTK::CG::Int32Type, :integer,   0)
		difftype_assert(:fp2ui, RLTK::CG::Double.new(1.7),   RLTK::CG::Int32Type, :integer,   1)
	end

	def test_fp2si
		difftype_assert(:fp2si, RLTK::CG::Double.new(-123.3), RLTK::CG::Int32Type, :integer, -123)
		difftype_assert(:fp2si, RLTK::CG::Double.new(0.7),    RLTK::CG::Int32Type, :integer,    0)
		difftype_assert(:fp2si, RLTK::CG::Double.new(1.7),    RLTK::CG::Int32Type, :integer,    1)
	end

	def test_fpext
		fconv_assert(:fp_ext, RLTK::CG::Float.new(123.0), RLTK::CG::DoubleType, 123.0)
		fconv_assert(:fp_ext, RLTK::CG::Float.new(123.0), RLTK::CG::FloatType,  123.0)
	end

	def test_fptrunc
		fconv_assert(:fp_trunc, RLTK::CG::Double.new(123.0), RLTK::CG::FloatType, 123.0)
	end

	def test_int64
		iconv_assert(:zext, RLTK::CG::Int64.new( 2**62 + 123), RLTK::CG::Int64Type, true,   2**62 + 123)
		iconv_assert(:zext, RLTK::CG::Int64.new(-2**62 - 123), RLTK::CG::Int64Type, true,  -2**62 - 123)
		iconv_assert(:zext, RLTK::CG::Int64.new( 2**63 + 123), RLTK::CG::Int64Type, false,  2**63 + 123)
	end

	def test_sext
		iconv_assert(:sext, RLTK::CG::Int1.new(1),  RLTK::CG::Int32Type, true,     -1)
		iconv_assert(:sext, RLTK::CG::Int8.new(-1), RLTK::CG::Int16Type, false, 65535)
	end

	def test_si2fp
		difftype_assert(:si2fp, RLTK::CG::Int32.new(257), RLTK::CG::FloatType,  :float, 257.0)
		difftype_assert(:si2fp, RLTK::CG::Int8.new(-1),   RLTK::CG::DoubleType, :float,  -1.0)
	end

	def test_truncate
		iconv_assert(:trunc, RLTK::CG::Int32.new(257), RLTK::CG::Int8Type, false, 1)
		iconv_assert(:trunc, RLTK::CG::Int32.new(123), RLTK::CG::Int1Type, false, 1)
		iconv_assert(:trunc, RLTK::CG::Int32.new(122), RLTK::CG::Int1Type, false, 0)
	end

	def test_ui2fp
		difftype_assert(:ui2fp, RLTK::CG::Int32.new(257), RLTK::CG::FloatType,  :float, 257.0)
		difftype_assert(:ui2fp, RLTK::CG::Int8.new(-1),   RLTK::CG::DoubleType, :float, 255.0)
	end

	def test_zext
		iconv_assert(:zext, RLTK::CG::Int16.new(257), RLTK::CG::Int32Type, false, 257)
	end

	##################
	# Helper Methods #
	##################

	def difftype_assert(op, operand, ret_type, assert_type, expected)
		res = run_convert(op, operand, ret_type)

		if assert_type == :integer then assert_equal(expected, res.to_i) else assert_in_delta(expected, res.to_f(ret_type), 0.001) end
	end

	def fcmp_assert(mode, operand0, operand1, expected)
		res = run_cmp(:fcmp, mode, RLTK::CG::Float.new(operand0), RLTK::CG::Float.new(operand1), RLTK::CG::Int1Type).to_i(false)
		assert_equal(expected.to_i, res)
	end

	def icmp_assert(mode, operand0, operand1, signed, expected)
		res = run_cmp(:icmp, mode, RLTK::CG::NativeInt.new(operand0, signed),
		              RLTK::CG::NativeInt.new(operand1, signed), RLTK::CG::Int1Type).to_i(false)

		assert_equal(expected.to_i, res)
	end

	def fconv_assert(op, operand, ret_type, expected)
		assert_in_delta(expected, run_convert(op, operand, ret_type).to_f(ret_type), 0.001)
	end

	def iconv_assert(op, operand, ret_type, signed, expected)
		assert_equal(expected, run_convert(op, operand, ret_type).to_i(signed))
	end

	def run_cmp(op, mode, operand0, operand1, ret_type)
		fun = @mod.functions.add("#{op}_#{mode}_tester", ret_type, []) do
			blocks.append { ret(self.send(op, mode, operand0, operand1)) }
		end

		@jit.run_function(fun)
	end

	def run_convert(op, operand, ret_type)
		fun = @mod.functions.add("#{op}_tester", ret_type, []) do
			blocks.append { ret(self.send(op, operand, ret_type)) }
		end

		@jit.run_function(fun)
	end
end
