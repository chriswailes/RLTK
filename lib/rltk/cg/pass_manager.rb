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

module RLTK::CG
	class PassManager
		include BindingClass
		
		
		# A list of passes that are available to be added to the pass
		# manager via the PassManager::add method.  They may either be
		# specified via the keys for this hash or any string that will be
		# turned into a string (via the Bindings::get_bname method) appearing
		# as a value.
		PASSES = {
			:ADCE			=> 'agressive_dce',
			:AlwaysInline		=> 'always_inliner',
			:ArgPromote		=> 'argument_promotion',
			:BasicAliasAnalysis	=> 'basic_alias_analysis',
			:CFGSimplify		=> 'cfg_simplification',
			:ConstMerge		=> 'constant_merge_pass',
			:ConstProp		=> 'constant_propagation_pass',
			:CorValProp		=> 'correlated_value_propagation',
			:DAE				=> 'dead_arg_elimination',
			:DSE				=> 'dead_store_elimination',
			:DemoteMemToReg	=> 'demote_memory_to_register',
			:EarlyCSE			=> 'early_cse',
			:FunctionAttrs		=> 'function_attrs',
			:FunctionInline	=> 'function_inlining',
			:GDCE			=> 'global_dce',
			:GlobalOpt		=> 'global_optimizer',
			:GVN				=> 'gvn',
			:Internalize		=> 'internalize',
			:IndVarSimplify	=> 'ind_var_simplify',
			:InstCombine		=> 'instruction_combining_pass',
			:IPConstProp		=> 'ip_constant_propagation',
			:IPSCCP			=> 'ipsccp',
			:JumpThreading		=> 'jump_threading',
			:LICM			=> 'licm',
			:LoopDeletion		=> 'loop_deletion',
			:LoopIdiom		=> 'loop_idiom',
			:LoopRotate		=> 'loop_rotate',
			:LoopUnroll		=> 'loop_unroll',
			:LoopUnswitch		=> 'loop_unswitch',
			:LEI				=> 'lower_expect_intrinsics',
			:MemCopyOpt		=> 'mem_cpy_opt',
			:PromoteMemToReg	=> 'promote_memory_to_register',
			:PruneEH			=> 'prune_eh',
			:Reassociate		=> 'reassociate',
			:SCCP			=> 'sccp',
			:ScalarRepl		=> 'scalar_repl_aggregates_pass',
			:SimplifyLibCalls	=> 'simplify_lib_calls'
			:StripDeadProtos	=> 'strip_dead_prototypes',
			:StripSymbols		=> 'strip_symbols',
			:TailCallElim		=> 'tail_call_elimination',
			:TBAA			=> 'type_based_alias_analysis',
			:Verifier			=> 'verifier'
		}
		
		def initialize(engine)
			# LLVM Initialization
			@ptr = Bindings.create_pass_manager
			
			Bindings.add_target_data(Bindings.get_execution_engine_target_data(engine), @ptr)
			
			# RLTK Initialization
			@enabled = Array.new
		end
		
		def dispose
			if @ptr
				self.finalize
				
				Bindings.dispose_pass_manager(@ptr)
				
				@ptr = nil
			end
		end
		
		def add(name)
			if PASSES.has_key?(name)
				return if @nabled.include?(name)
				
				Bindings.send("add_#{PASSES[name]}_pass", @ptr)
				
				@enabled << name
				
			elsif PASSES.has_value?(bname = Bindings.get_bname(name))
				return if @enabled.include?(PASSES.key(bname))
				
				Bindings.send("add_#{bname}_pass", @ptr)
				
				@enabled << PASSES.key(bname)
				
			else
				raise "Unknown pass: #{name}"
			end
			
			self
		end
		alias :<< :add
		
		def enabled
			@enabled.clone
		end
		
		def enabled?(name)
			@enabled.include?(name) or @enabled.include?(PASSES.key(Bindings.get_bname(name)))
		end
		
		def run(mod)
			Bindings.run_pass_manager(@ptr, mod).to_bool
		end
		
		protected
		def finalize
		end
	end
	
	class FunctionPassmanager < PassManager
		def initialize(engine, mod)
			@ptr = Bindings.create_function_pass_manager_for_module(mod)
			
			Bindings.add_target_data(Bidnings.get_execution_engine_target_data(engine), @ptr)
			
			Bindings.initialize_function_pass_manager(@ptr).to_bool
		end
		
		def run(fun)
			Bindings.run_function_pass_manager(@ptr, fun).to_bool
		end
		
		protected
		def finalize
			Bindings.finalize_function_pass_manager(@ptr).to_bool
		end
	end
end
