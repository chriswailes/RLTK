# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/12/23
# Description:	This file sets up a contractor and JITing execution engine for
#			Kazoo.

# RLTK Files
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/execution_engine'
require 'rltk/cg/contractor'

# Inform LLVM that we will be targeting an x86 architecture.
RLTK::CG::LLVM.init(:X86)

module Kazoo
	class Contractor < RLTK::CG::Contractor
		attr_reader :module

		def initialize
			super

			# IR building objects.
			@module = RLTK::CG::Module.new('Kazoo JIT')
			@st     = Hash.new

			# Execution Engine
			@engine = RLTK::CG::JITCompiler.new(@module)

			# Add passes to the Function Pass Manager.
			@module.fpm.add(:InstCombine, :Reassociate, :GVN, :CFGSimplify)
		end

		def add(ast)
			case ast
			when Expression          then visit Function.new(Prototype.new('', []), ast)
			when Function, Prototype then visit ast
			else raise 'Attempting to add an unhandled node type to the JIT.'
			end
		end

		def execute(fun, *args)
			@engine.run_function(fun, *args)
		end

		def optimize(fun)
			@module.fpm.run(fun)

			fun
		end

		on Binary do |node|
			left  = visit node.left
			right = visit node.right

			case node
			when Add then fadd(left, right, 'addtmp')
			when Sub then fsub(left, right, 'subtmp')
			when Mul then fmul(left, right, 'multmp')
			when Div then fdiv(left, right, 'divtmp')
			when LT  then ui2fp(fcmp(:ult, left, right, 'cmptmp'), RLTK::CG::DoubleType, 'booltmp')
			end
		end

		on Call do |node|
			callee = @module.functions[node.name]

			if not callee
				raise 'Unknown function referenced.'
			end

			if callee.params.size != node.args.length
				raise "Function #{node.name} expected #{callee.params.size} argument(s) but was called with #{node.args.length}."
			end

			args = node.args.map { |arg| visit arg }
			call callee, *args.push('calltmp')
		end

		on Variable do |node|
			if @st.key?(node.name)
				@st[node.name]
			else
				raise "Unitialized variable '#{node.name}'."
			end
		end

		on Number do |node|
			RLTK::CG::Double.new(node.value)
		end

		on Function do |node|
			# Reset the symbol table.
			@st.clear

			# Translate the function's prototype.
			fun = visit node.proto

			# Create a new basic block to insert into, translate the
			# expression, and set its value as the return value.
			ret(visit node.body, at: fun.blocks.append('entry'))

			# Verify the function and return it.
			fun.tap { fun.verify }
		end

		on Prototype do |node|
			if fun = @module.functions[node.name]
				if fun.blocks.size != 0
					raise "Redefinition of function #{node.name}."

				elsif fun.params.size != node.arg_names.length
					raise "Redefinition of function #{node.name} with different number of arguments."
				end
			else
				fun = @module.functions.add(node.name, RLTK::CG::DoubleType, Array.new(node.arg_names.length, RLTK::CG::DoubleType))
			end

			# Name each of the function paramaters.
			fun.tap do
				node.arg_names.each_with_index do |name, i|
					(@st[name] = fun.params[i]).name = name
				end
			end
		end
	end
end
