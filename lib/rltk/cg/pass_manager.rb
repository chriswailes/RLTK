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

	# A PassManager is responsible for scheduling and running optimization
	# passes on modules.
	class PassManager
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_pass_manager(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# A list of passes that are available to be added to the pass
		# manager via the {PassManager#add} method.
		PASSES = {
			:ADCE               => :aggressive_dce,
			:AlwaysInline       => :always_inliner,
			:ArgPromote         => :argument_promotion,
			:BasicAliasAnalysis => :basic_alias_analysis,
			:BBVectorize        => :bb_vectorize,
			:CFGSimplify        => :cfg_simplification,
			:ConstMerge         => :constant_merge,
			:ConstProp          => :constant_propagation,
			:CorValProp         => :correlated_value_propagation,
			:DAE                => :dead_arg_elimination,
			:DSE                => :dead_store_elimination,
			:DemoteMemToReg     => :demote_memory_to_register,
			:EarlyCSE           => :early_cse,
			:FunctionAttrs      => :function_attrs,
			:FunctionInline     => :function_inlining,
			:GDCE               => :global_dce,
			:GlobalOpt          => :global_optimizer,
			:GVN                => :gvn,
			:Internalize        => :internalize,
			:IndVarSimplify     => :ind_var_simplify,
			:InstCombine        => :instruction_combining,
			:IPConstProp        => :ip_constant_propagation,
			:IPSCCP             => :ipsccp,
			:JumpThreading      => :jump_threading,
			:LICM               => :licm,
			:LoopDeletion       => :loop_deletion,
			:LoopIdiom          => :loop_idiom,
			:LoopReroll         => :loop_reroll,
			:LoopRotate         => :loop_rotate,
			:LoopUnroll         => :loop_unroll,
			:LoopUnswitch       => :loop_unswitch,
			:LoopVectorize      => :loop_vectorize,
			:LEI                => :lower_expect_intrinsics,
			:MemCopyOpt         => :mem_cpy_opt,
			:PILC               => :partially_inline_lib_calls,
			:PromoteMemToReg    => :promote_memory_to_register,
			:PruneEH            => :prune_eh,
			:Reassociate        => :reassociate,
			:SCCP               => :sccp,
			:ScalarRepl         => :scalar_repl_aggregates,
			:SimplifyLibCalls   => :simplify_lib_calls,
			:SLPVectorize       => :slp_vectorize,
			:StripDeadProtos    => :strip_dead_prototypes,
			:StripSymbols       => :strip_symbols,
			:TailCallElim       => :tail_call_elimination,
			:TBAA               => :type_based_alias_analysis,
			:Verifier           => :verifier
		}

		# Create a new pass manager.  You should never have to do this as
		# {Module Modules} should create PassManagers for you whenever they
		# are requested.
		#
		# @see Module#pass_manager
		#
		# @param [Module] mod Module this pass manager belongs to.
		def initialize(mod)
			# LLVM Initialization
			@ptr = Bindings.create_pass_manager
			@mod = mod

			# Set the target data if the module is associated with a execution engine.
			self.target_data = mod.engine.target_data if mod.engine

			# RLTK Initialization
			@enabled = Array.new

			# Define a finalizer to free the memory used by LLVM for this
			# pass manager.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
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

		# Set the target data for this pass manager.
		#
		# @param [TargetData] data
		#
		# @return [void]
		def target_data=(data)
			Bindings.add_target_data(check_type(data, TargetData, 'data'), @ptr)
		end

		protected
		# Empty method used by {FunctionPassManager} to clean up resources.
		def finalize
		end
	end

	# A FunctionPassManager is responsible for scheduling and running optimization
	# passes on individual functions inside the context of a module.
	class FunctionPassManager < PassManager
		# Create a new function pass manager.  You should never have to do
		# this as {Module Modules} should create FunctionPassManagers for you
		# whenever they are requested.
		#
		# @see Module#function_pass_manager
		#
		# @param [Module] mod Module this pass manager belongs to.
		def initialize(mod)
			# LLVM Initialization
			@ptr = Bindings.create_function_pass_manager_for_module(mod)

			# Set the target data if the module is associated with a execution engine.
			self.target_data = mod.engine.target_data if mod.engine

			Bindings.initialize_function_pass_manager(@ptr)

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

	PASS_GROUPS = [
		:analysis,
		:core,
		:inst_combine,
		:instrumentation,
		:ipa,
		:ipo,
		:objc_arc_opts,
		:scalar_opts,
		:target,
		:transform_utils,
		:vectorization
	]

	class PassRegistry
		include BindingClass

		def self.global
			PassRegistry.allocate.tap { |pr| pr.ptr = Bindings.get_global_pass_registry }
		end

		def initialize
			@ptr = Bindings::OpaquePassRegistry.new
		end

		def init(pass_group = :all)
			if pass_group == :all
				PASS_GROUPS.each { |pg| Bindings.send("initialize_#{pg}", @ptr) }

			elsif PASS_GROUPS.include?(pass_group)
				Bindings.send("initialize_#{pass_group}", @ptr)
			end
		end

		def init(pass_group)

		end
	end
end
