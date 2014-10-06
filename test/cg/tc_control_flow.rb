# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/09
# Description:	This file contains unit tests for control flow instructions.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/execution_engine'
require 'rltk/cg/module'
require 'rltk/cg/function'
require 'rltk/cg/type'

class ControlFlowTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)

		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end

	##############
	# Call Tests #
	##############

	def test_external_call
		extern = @mod.functions.add('abs', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType])

		fun = @mod.functions.add('external_call_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType]) do |fun|
			blocks.append { ret call(extern, fun.params[0]) }
		end

		assert_equal(10, @jit.run_function(fun, -10).to_i)
	end

	def test_external_string_call
		global = @mod.globals.add(RLTK::CG::ArrayType.new(RLTK::CG::Int8Type, 5), "path")
		global.linkage = :internal
		global.initializer = RLTK::CG::ConstantString.new('PATH')

		external = @mod.functions.add('getenv', RLTK::CG::PointerType.new(RLTK::CG::Int8Type), [RLTK::CG::PointerType.new(RLTK::CG::Int8Type)])

		fun = @mod.functions.add('external_string_call_tester', RLTK::CG::PointerType.new(RLTK::CG::Int8Type), []) do
			blocks.append do
				param = gep(global, [RLTK::CG::NativeInt.new(0), RLTK::CG::NativeInt.new(0)])

				ret call(external, param)
			end
		end

		assert_equal(ENV['PATH'], @jit.run_function(fun).ptr.read_pointer.read_string)
	end

	def test_nested_call
		fun0 = @mod.functions.add('simple_call_tester0', RLTK::CG::NativeIntType, []) do
			blocks.append { ret RLTK::CG::NativeInt.new(1) }
		end

		fun1 = @mod.functions.add('simple_call_tester1', RLTK::CG::NativeIntType, []) do
			blocks.append { ret call(fun0) }
		end

		assert_equal(1, @jit.run_function(fun1).to_i)
	end

	def test_recursive_call
		fun = @mod.functions.add('recursive_call_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType]) do |fun|
			entry	= blocks.append
			recurse	= blocks.append
			exit		= blocks.append

			entry.build do
				cond(icmp(:uge, fun.params[0], RLTK::CG::NativeInt.new(5)), exit, recurse)
			end

			result =
			recurse.build do
				call(fun, add(fun.params[0], RLTK::CG::NativeInt.new(1))).tap { br exit }
			end

			exit.build do
				ret(phi(RLTK::CG::NativeIntType, {entry => fun.params[0], recurse => result}))
			end
		end

		assert_equal(5, @jit.run_function(fun, 1).to_i)
		assert_equal(6, @jit.run_function(fun, 6).to_i)
	end

	##############
	# Jump Tests #
	##############

	def test_cond_jump
		fun = @mod.functions.add('direct_jump_tester', RLTK::CG::NativeIntType, []) do |fun|
			entry = blocks.append

			bb0 = blocks.append { ret RLTK::CG::NativeInt.new(1) }
			bb1 = blocks.append { ret RLTK::CG::NativeInt.new(0) }

			entry.build do
				cond(icmp(:eq, RLTK::CG::NativeInt.new(1), RLTK::CG::NativeInt.new(2)), bb0, bb1)
			end
		end

		assert_equal(0, @jit.run_function(fun).to_i)
	end

	def test_direct_jump
		fun = @mod.functions.add('direct_jump_tester', RLTK::CG::NativeIntType, []) do |fun|
			entry = blocks.append

			bb0 = blocks.append { ret(RLTK::CG::NativeInt.new(1)) }
			bb1 = blocks.append { ret(RLTK::CG::NativeInt.new(0)) }

			entry.build { br bb1 }
		end

		assert_equal(0, @jit.run_function(fun).to_i)
	end

	def test_switched_jump
		fun = @mod.functions.add('direct_jump_tester', RLTK::CG::NativeIntType, []) do |fun|
			entry = blocks.append

			bb0 = blocks.append { ret RLTK::CG::NativeInt.new(1) }
			bb1 = blocks.append { ret RLTK::CG::NativeInt.new(0) }

			entry.build do
				switch(RLTK::CG::NativeInt.new(1), bb0, {RLTK::CG::NativeInt.new(1) => bb1})
			end
		end

		assert_equal(0, @jit.run_function(fun).to_i)
	end

	##############
	# Misc Tests #
	##############

	def test_select
		fun = @mod.functions.add('select_tester', RLTK::CG::Int1Type, [RLTK::CG::NativeIntType]) do |fun|
			blocks.append do
				ret select(fun.params[0], RLTK::CG::Int1.new(0), RLTK::CG::Int1.new(1))
			end
		end

		assert_equal(0, @jit.run_function(fun, 1).to_i(false))
		assert_equal(1, @jit.run_function(fun, 0).to_i(false))
	end

	#############
	# Phi Tests #
	#############

	def test_phi
		fun = @mod.functions.add('phi_tester', RLTK::CG::NativeIntType, [RLTK::CG::NativeIntType]) do |fun|
			entry	= blocks.append('entry')
			block0	= blocks.append('block0')
			block1	= blocks.append('block1')
			exit		= blocks.append('exit')

			entry.build do
				cond(icmp(:eq, fun.params[0], RLTK::CG::NativeInt.new(0)), block0, block1)
			end

			result0 =
			block0.build do
				add(fun.params[0], RLTK::CG::NativeInt.new(1)).tap { br(exit) }
			end

			result1 =
			block1.build do
				sub(fun.params[0], RLTK::CG::NativeInt.new(1)).tap { br(exit) }
			end

			exit.build do
				ret(phi(RLTK::CG::NativeIntType, {block0 => result0, block1 => result1}))
			end
		end

		assert_equal(1, @jit.run_function(fun, 0).to_i)
		assert_equal(0, @jit.run_function(fun, 1).to_i)
	end
end
