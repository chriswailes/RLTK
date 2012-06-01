# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the PassManager class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
	# A PassManager is responsible for scheduling and running optimization
	# passes on modules.
	class PassManager
		include BindingClass
		
		# A list of passes that are available to be added to the pass
		# manager via the {PassManager#add} method.
		PASSES = {
			:ADCE			=> :agressive_dce,
			:AlwaysInline		=> :always_inliner,
			:ArgPromote		=> :argument_promotion,
			:BasicAliasAnalysis	=> :basic_alias_analysis,
			:CFGSimplify		=> :cfg_simplification,
			:ConstMerge		=> :constant_merge,
			:ConstProp		=> :constant_propagation,
			:CorValProp		=> :correlated_value_propagation,
			:DAE				=> :dead_arg_elimination,
			:DSE				=> :dead_store_elimination,
			:DemoteMemToReg	=> :demote_memory_to_register,
			:EarlyCSE			=> :early_cse,
			:FunctionAttrs		=> :function_attrs,
			:FunctionInline	=> :function_inlining,
			:GDCE			=> :global_dce,
			:GlobalOpt		=> :global_optimizer,
			:GVN				=> :gvn,
			:Internalize		=> :internalize,
			:IndVarSimplify	=> :ind_var_simplify,
			:InstCombine		=> :instruction_combining,
			:IPConstProp		=> :ip_constant_propagation,
			:IPSCCP			=> :ipsccp,
			:JumpThreading		=> :jump_threading,
			:LICM			=> :licm,
			:LoopDeletion		=> :loop_deletion,
			:LoopIdiom		=> :loop_idiom,
			:LoopRotate		=> :loop_rotate,
			:LoopUnroll		=> :loop_unroll,
			:LoopUnswitch		=> :loop_unswitch,
			:LEI				=> :lower_expect_intrinsics,
			:MemCopyOpt		=> :mem_cpy_opt,
			:PromoteMemToReg	=> :promote_memory_to_register,
			:PruneEH			=> :prune_eh,
			:Reassociate		=> :reassociate,
			:SCCP			=> :sccp,
			:ScalarRepl		=> :scalar_repl_aggregates,
			:SimplifyLibCalls	=> :simplify_lib_calls,
			:StripDeadProtos	=> :strip_dead_prototypes,
			:StripSymbols		=> :strip_symbols,
			:TailCallElim		=> :tail_call_elimination,
			:TBAA			=> :type_based_alias_analysis,
			:Verifier			=> :verifier
		}
		
		# Creat a new pass manager.  You should never have to do this as
		# {ExecutionEngine ExecutionEngines} creates a PassManager whenever
		# one is requested.
		#
		# @param [ExecutionEngine]	engine	ExecutionEngine this pass manager belongs to.
		# @param [Module]			mod		Module this pass manager belongs to.
		def initialize(engine, mod)
			# LLVM Initialization
			@ptr = Bindings.create_pass_manager
			@mod = mod
			
			Bindings.add_target_data(Bindings.get_execution_engine_target_data(engine), @ptr)
			
			# RLTK Initialization
			@enabled = Array.new
		end
		
		# Frees the resources used by LLVM for this pass manager.
		#
		# @return [void]
		def dispose
			if @ptr
				self.finalize
				
				Bindings.dispose_pass_manager(@ptr)
				
				@ptr = nil
			end
		end
		
		# Add a pass or passes to this pass manager.  Passes may either be
		# specified via the keys for the PASSES hash or any string that will
		# be turned into a string (via the {Bindings.get_bname} method)
		# appearing as a value of the PASSES hash.
		#
		# @see PASSES
		#
		# @param [Array<Symbol>] names Passes to add to the pass manager.
		#
		# @return [PassManager] self
		def add(*names)
			names.each do |name|
				name = name.to_sym
				
				if PASSES.has_key?(name)
					next if @enabled.include?(name)
				
					Bindings.send("add_#{PASSES[name]}_pass", @ptr)
				
					@enabled << name
				
				elsif PASSES.has_value?(bname = Bindings.get_bname(name))
					next if @enabled.include?(PASSES.key(bname))
				
					Bindings.send("add_#{bname}_pass", @ptr)
				
					@enabled << PASSES.key(bname)
				
				else
					raise "Unknown pass: #{name}"
				end
			end
			
			self
		end
		alias :<< :add
		
		# @return [Array<Symbol>] List of passes that have been enabled.
		def enabled
			@enabled.clone
		end
		
		# @return [Boolean] Weather the pass has been enabled or not.
		def enabled?(name)
			@enabled.include?(name) or @enabled.include?(PASSES.key(Bindings.get_bname(name)))
		end
		
		# Run the enabled passes on the execution engine's module.
		#
		# @return [void]
		def run
			Bindings.run_pass_manager(@ptr, @mod).to_bool
		end
		
		protected
		# Empty method used by {FunctionPassManager} to clean up resources.
		def finalize
		end
	end
	
	# A FunctionPassManager is responsible for scheduling and running optimization
	# passes on individual functions inside the context of a module.
	class FunctionPassManager < PassManager
		# Creat a new function pass manager.  You should never have to do
		# this as {ExecutionEngine ExecutionEngines} creates a
		# FunctionPassManager whenever one is requested.
		#
		# @param [ExecutionEngine]	engine	ExecutionEngine this pass manager belongs to.
		# @param [Module]			mod		Module this pass manager belongs to.
		def initialize(engine, mod)
			# LLVM Initialization
			@ptr = Bindings.create_function_pass_manager_for_module(mod)
			
			Bindings.add_target_data(Bindings.get_execution_engine_target_data(engine), @ptr)
			
			Bindings.initialize_function_pass_manager(@ptr).to_bool
			
			# RLTK Initialization
			@enabled = Array.new
		end
		
		# Run the enabled passes on the given function inside the execution
		# engine's module.
		#
		# @param [Function] fun Function to optimize.
		#
		# @return [void]
		def run(fun)
			Bindings.run_function_pass_manager(@ptr, fun).to_bool
		end
		
		protected
		# Called by {#dispose} to finalize any operations of the function
		# pass manager.
		#
		# @return [void]
		def finalize
			Bindings.finalize_function_pass_manager(@ptr).to_bool
		end
	end
end
