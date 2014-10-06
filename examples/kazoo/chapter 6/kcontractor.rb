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

		on If do |node|
			cond_val = fcmp :one, (visit node.cond), ZERO, 'ifcond'

			start_bb	= current_block
			fun		= start_bb.parent

			then_bb				= fun.blocks.append('then')
			then_val, new_then_bb	= visit node.then, at: then_bb, rcb: true

			else_bb				= fun.blocks.append('else')
			else_val, new_else_bb	= visit node.else, at: else_bb, rcb: true

			merge_bb = fun.blocks.append('merge', self)
			phi_inst = build(merge_bb) { phi RLTK::CG::DoubleType, {new_then_bb => then_val, new_else_bb => else_val}, 'iftmp' }

			build(start_bb) { cond cond_val, then_bb, else_bb }

			build(new_then_bb) { br merge_bb }
			build(new_else_bb) { br merge_bb }

			phi_inst.tap { target merge_bb }
		end

		on For do |node|
			ph_bb		= current_block
			fun			= ph_bb.parent
			loop_cond_bb	= fun.blocks.append('loop_cond')

			init_val = visit node.init
			br loop_cond_bb

			var = build(loop_cond_bb) { phi RLTK::CG::DoubleType, {ph_bb => init_val}, node.var }

			old_var = @st[node.var]
			@st[node.var] = var

			end_cond = fcmp :one, (visit node.cond), ZERO, 'loopcond'

			loop_bb0 = fun.blocks.append('loop')

			_, loop_bb1 = visit node.body, at: loop_bb0, rcb: true

			step_val = visit node.step
			next_var = fadd var, step_val, 'nextvar'

			var.incoming.add({loop_bb1 => next_var})

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
