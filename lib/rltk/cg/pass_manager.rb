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
		
		# A list of passes that are available to be added to the pass
		# manager via the PassManager::add method.  They may either be
		# specified via the keys for this hash or any string that will be
		# turned into a string (via the Bindings::get_bname method) appearing
		# as a value.
		PASSES = {
			:ADCE			=> 'agressive_dce',
			:SimplifyCFG		=> 'cfg_simplification',
			:DSE				=> 'dead_store_elimination',
			:GDCE			=> 'global_dce',
			:GVN				=> 'gvn',
			:IndVars			=> 'ind_vars',
			:Inline			=> 'function_inlining',
			:InstCombine		=> 'instruction_combining_pass',
			:JumpThreading		=> 'jump_threading',
			:LICM			=> 'licm',
			:LoopDeletion		=> 'loop_deletion',
			:LoopRotate		=> 'loop_rotate',
			:LoopUnroll		=> 'loop_unroll',
			:LoopUnswitch		=> 'loop_unswitch',
			:MemCopyOpt		=> 'mem_cpy_opt',
			:MemToReg			=> 'promote_memory_to_register',
			:Reassociate		=> 'reassociate',
			:SCCP			=> 'sccp',
			:ScalarRepl		=> 'scalar_repl_aggregates_pass',
			:SimplifyLibCalls	=> 'simplify_lib_calls'
			:TailCallElim		=> 'tail_call_elimination',
			:ConstProp		=> 'constant_propagation_pass',
			:RegToMem			=> 'demote_memory_to_register'
		}
		
		def initialize(engine)
			# LLVM Initialization
			@ptr = Bindings.create_pass_manager
			
			Bindings.add_target_data(Bindings.get_execution_engine_target_data(engine), @ptr)
			
			# RLTK Initialization
			@enabled = Array.new
		end
		
		def dispose
			if not @ptr.nil?
				self.finalize
				
				Bindings.dispose_pass_manager(@ptr)
				
				@ptr = nil
			end
		end
		
		def add(name)
			if PASSES.has_key?(name)
				Bindings.send("add_#{PASSES[name]}_pass", @ptr)
				
				@enabled << name
				
			elsif PASSES.has_value?(bname = Bindings.get_bname(name))
				Bindings.send("add_#{bname}_pass", @ptr)
				
				@enabled << PASSES.key(bname)
			end
			
			self
		end
		alias :add :<<
		
		def enabled
			@enabled.clone
		end
		
		def run(mod)
			Bindings.run_pass_manager(@ptr, mod) != 0
		end
		
		protected
		def finalize
		end
	end
	
	class FunctionPassmanager < PassManager
		def initialize(engine, mod)
			@ptr = Bindings.create_function_pass_manager_for_module(mod)
			
			Bindings.add_target_data(Bidnings.get_execution_engine_target_data(engine), @ptr)
			
			Bindings.initialize_function_pass_manager(@ptr) != 0
		end
		
		def run(fun)
			Bindings.run_function_pass_manager(@ptr, fun) != 0
		end
		
		protected
		def finalize
			Bindings.finalize_function_pass_manager(@ptr) != 0
		end
	end
end
