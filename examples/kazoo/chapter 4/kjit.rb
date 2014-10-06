# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/11
# Description:	This file sets up a JITing execution engine for Kazoo.

# RLTK Files
require 'rltk/cg/llvm'
require 'rltk/cg/module'

# Inform LLVM that we will be targeting an x86 architecture.
RLTK::CG::LLVM.init(:X86)

module Kazoo
	class JIT
		attr_reader :module

		def initialize
			# IR building objects.
			@module	= RLTK::CG::Module.new('Kazoo JIT')
			@builder	= RLTK::CG::Builder.new
			@st		= Hash.new
		end

		def add(ast)
			case ast
			when Expression	then translate_function(Function.new(Prototype.new('', []), ast))
			when Function		then translate_function(ast)
			when Prototype		then translate_prototype(ast)
			else raise 'Attempting to add an unhandled node type to the JIT.'
			end
		end

		def translate_expression(node)
			case node
			when Binary
				left  = translate_expression(node.left)
				right = translate_expression(node.right)

				case node
				when Add
					@builder.fadd(left, right, 'addtmp')

				when Sub
					@builder.fsub(left, right, 'subtmp')

				when Mul
					@builder.fmul(left, right, 'multmp')

				when Div
					@builder.fdiv(left, right, 'divtmp')

				when LT
					cond = @builder.fcmp(:ult, left, right, 'cmptmp')
					@builder.ui2fp(cond, RLTK::CG::DoubleType, 'booltmp')
				end

			when Call
				callee = @module.functions[node.name]

				if not callee
					raise 'Unknown function referenced.'
				end

				if callee.params.size != node.args.length
					raise "Function #{node.name} expected #{callee.params.size} argument(s) but was called with #{node.args.length}."
				end

				args = node.args.map { |arg| translate_expression(arg) }
				@builder.call(callee, *args.push('calltmp'))

			when Variable
				if @st.key?(node.name)
					@st[node.name]
				else
					raise "Unitialized variable '#{node.name}'."
				end

			when Number
				RLTK::CG::Double.new(node.value)

			else
				raise 'Unhandled expression type encountered.'
			end
		end

		def translate_function(node)
			# Reset the symbol table.
			@st.clear

			# Translate the function's prototype.
			fun = translate_prototype(node.proto)

			# Create a new basic block to insert into, translate the
			# expression, and set its value as the return value.
			fun.blocks.append('entry', @builder, nil, self) do |jit|
				ret jit.translate_expression(node.body)
			end

			# Verify the function and return it.
			returning(fun) { fun.verify }
		end

		def translate_prototype(node)
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
			returning(fun) do
				node.arg_names.each_with_index do |name, i|
					(@st[name] = fun.params[i]).name = name
				end
			end
		end
	end
end
