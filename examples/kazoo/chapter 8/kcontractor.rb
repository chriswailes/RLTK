# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/12/23
# Description:	This file sets up a contractor and JITing execution engine for
#			Kazoo.

# RLTK Files
require 'rltk/cg/llvm'
require 'rltk/cg/module'
require 'rltk/cg/execution_engine'
require 'rltk/cg/value'
require 'rltk/cg/contractor'

# Inform LLVM that we will be targeting an x86 architecture.
RLTK::CG::LLVM.init(:X86)

module Kazoo

	ZERO = RLTK::CG::Double.new(0.0)

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
			@module.fpm.add(:InstCombine, :Reassociate, :GVN, :CFGSimplify, :PromoteMemToReg)
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

		on Assign do
			right = visit node.right

			loc =
			if @st.has_key?(node.name)
				@st[node.name]
			else
				@st[node.name] = alloca RLTK::CG::DoubleType, node.name
			end

			store right, loc
		end

		on Binary do |node|
			left  = visit node.left
			right = visit node.right

			case node
			when Add then fadd(left, right, 'addtmp')
			when Sub then fsub(left, right, 'subtmp')
			when Mul then fmul(left, right, 'multmp')
			when Div then fdiv(left, right, 'divtmp')
			when LT  then ui2fp(fcmp(:ult, left, right, 'cmptmp'), RLTK::CG::DoubleType, 'lttmp')
			when GT  then ui2fp(fcmp(:ugt, left, right, 'cmptmp'), RLTK::CG::DoubleType, 'gttmp')
			when Eql then ui2fp(fcmp(:ueq, left, right, 'cmptmp'), RLTK::CG::DoubleType, 'eqtmp')
			when Or
				left  = fcmp :une,  left, ZERO, 'lefttmp'
				right = fcmp :une, right, ZERO, 'righttmp'

				ui2fp (self.or left, right, 'ortmp'), RLTK::CG::DoubleType, 'orltmp'

			when And
				left  = fcmp :une,  left, ZERO, 'lefttmp'
				right = fcmp :une, right, ZERO, 'rightmp'

				ui2fp (self.and left, right, 'andtmp'), RLTK::CG::DoubleType, 'andtmp'

			else	right
			end
		end

		on Unary do |node|
			op = visit node.operand

			case node
			when Neg
				fneg op, 'negtmp'

			when Not
				cond = fcmp :ueq, op, ZERO, 'cmptmp'
				int	= self.not cond, 'nottmp'

				ui2fp int, RLTK::CG::DoubleType, 'booltmp'
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
				self.load @st[node.name], node.name
			else
				raise "Unitialized variable '#{node.name}'."
			end
		end

		on Number do |node|
			RLTK::CG::Double.new(node.value)
		end

		on If do |node|
			cond_val = fcmp :one, (visit node.cond), ZERO, 'ifcond'

			start_bb = current_block
			fun      = start_bb.parent

			then_bb               = fun.blocks.append('then')
			then_val, new_then_bb = visit node.then, at: then_bb, rcb: true

			else_bb               = fun.blocks.append('else')
			else_val, new_else_bb = visit node.else, at: else_bb, rcb: true

			merge_bb = fun.blocks.append('merge', self)
			phi_inst = build(merge_bb) { phi RLTK::CG::DoubleType, {new_then_bb => then_val, new_else_bb => else_val}, 'iftmp' }

			build(start_bb) { cond cond_val, then_bb, else_bb }

			build(new_then_bb) { br merge_bb }
			build(new_else_bb) { br merge_bb }

			phi_inst.tap { target merge_bb }
		end

		on For do |node|
			ph_bb        = current_block
			fun          = ph_bb.parent
			loop_cond_bb = fun.blocks.append('loop_cond')

			loc = alloca RLTK::CG::DoubleType, node.var
			store (visit node.init), loc

			old_var = @st[node.var]
			@st[node.var] = loc

			br loop_cond_bb

			end_cond = fcmp :one, (visit node.cond, at: loop_cond_bb), ZERO, 'loopcond'

			loop_bb0 = fun.blocks.append('loop')

			_, loop_bb1 = visit node.body, at: loop_bb0, rcb: true

			step_val	= visit node.step
			var		= self.load loc, node.var
			next_var	= fadd var, step_val, 'nextvar'
			store next_var, loc

			br loop_cond_bb

			# Add the conditional branch to the loop_cond_bb.
			after_bb = fun.blocks.append('afterloop')

			build(loop_cond_bb) { cond end_cond, loop_bb0, after_bb }

			target after_bb

			@st[node.var] = old_var

			ZERO
		end

		on Function do |node|
			# Reset the symbol table.
			@st.clear

			# Translate the function's prototype.
			fun = visit node.proto

			# Create a new basic block to insert into, allocate space for
			# the arguments, store their values, translate the expression,
			# and set its value as the return value.
			build(fun.blocks.append('entry')) do
				fun.params.each do |param|
					@st[param.name] = alloca RLTK::CG::DoubleType, param.name
					store param, @st[param.name]
				end

				ret (visit node.body)
			end

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
					fun.params[i].name = name
				end
			end
		end
	end
end
