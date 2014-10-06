# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/11
# Description:	This file contains unit tests for the mechanics beind
#			transformation passes.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/execution_engine'
require 'rltk/cg/type'
require 'rltk/cg/value'

class TransformTester < Minitest::Test
	def setup
		RLTK::CG::LLVM.init(:X86)

		@mod = RLTK::CG::Module.new('Testing Module')
		@jit = RLTK::CG::JITCompiler.new(@mod)
	end

	def test_gdce
		fn0 = @mod.functions.add('fn0', RLTK::CG::VoidType, []) do |fun|
			fun.linkage = :internal

			blocks.append do
				ret_void
			end
		end

		fn1 = @mod.functions.add('fn1', RLTK::CG::VoidType, []) do |fun|
			fun.linkage = :internal

			blocks.append do
				ret_void
			end
		end

		main = @mod.functions.add('main', RLTK::CG::VoidType, []) do
			blocks.append do
				call(fn0)
				ret_void
			end
		end

		funs = @mod.functions.to_a

		assert(funs.include?(fn0))
		assert(funs.include?(fn1))
		assert(funs.include?(main))

		@mod.pass_manager << :GDCE
		assert(@mod.pass_manager.run)

		funs = @mod.functions.to_a

		assert( funs.include?(fn0))
		assert(!funs.include?(fn1))
		assert( funs.include?(main))
	end
end
