# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the ExecutionEngine class, along with its
#			subclasses.

############
# Requires #
############

# Gems
require 'filigree/abstract_class'

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/pass_manager'
require 'rltk/cg/target'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# The ExecutionEngine class and its subclasses execute code from the
	# provided module, as well as providing a {PassManager} and
	# {FunctionPassManager} for optimizing modules.
	#
	# @abstract Implemented by {Interpreter} and {JITCompiler}.
	class ExecutionEngine
		include Filigree::AbstractClass
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_execution_engine(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# @return [Module]
		attr_reader :module

		# Create a new execution engine.
		#
		# @param [Module]	mod		Module to be executed.
		# @param [Proc]	block	Block used by subclass constructors.  Don't use this parameter.
		#
		# @raise [RuntimeError] An error is raised if something went horribly wrong inside LLVM during the creation of this engine.
		def initialize(mod, &block)
			check_type(mod, Module, 'mod')

			block = Proc.new { |ptr, error| Bindings.create_execution_engine_for_module(ptr, mod, error) } if block == nil

			ptr    = FFI::MemoryPointer.new(:pointer)
			error  = FFI::MemoryPointer.new(:pointer)
			status = block.call(ptr, error)

			if status.zero?
				@ptr    = ptr.read_pointer
				@module = mod

				# Associate this engine with the provided module.
				@module.engine = self

				# Define a finalizer to free the memory used by LLVM for
				# this execution engine.
				ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
			else
				errorp  = error.read_pointer
				message = errorp.null? ? 'Unknown' : errorp.read_string

				error.autorelease = false

				Bindings.dispose_message(error)

				raise "Error creating execution engine: #{message}"
			end
		end

		# Builds a pointer to a global value.
		#
		# @param [GlobalValue] global Value you want a pointer to.
		#
		# @return [FFI::Pointer]
		def pointer_to_global(global)
			Bindings.get_pointer_to_global(@ptr, global)
		end

		# Execute a function in the engine's module with the given arguments.
		# The arguments may be either GnericValue objects or any object that
		# can be turned into a GenericValue.
		#
		# @param [Function]					fun	Function object to be executed.
		# @param [Array<GenericValue, Object>]	args	Arguments to be passed to the function.
		#
		# @return [GenericValue]
		def run_function(fun, *args)
			new_args =
			fun.params.zip(args).map do |param, arg|
				if arg.is_a?(GenericValue) then arg else GenericValue.new(arg) end
			end

			args_ptr = FFI::MemoryPointer.new(:pointer, args.length)
			args_ptr.write_array_of_pointer(new_args)

			GenericValue.new(Bindings.run_function(@ptr, fun, args.length, args_ptr))
		end
		alias :run :run_function

		# Execute a function in the engine's module with the given arguments
		# as the main function of a program.
		#
		# @param [Function]		fun	Function object to be executed.
		# @param [Array<String>]	args	Arguments to be passed to the function.
		#
		# @return [GenericValue]
		def run_function_as_main(fun, *args)
			# Prepare the ARGV parameter.
			argv = FFI::MemoryPointer.new(:pointer, argc)
			argv.write_array_of_pointer(args.map { |str| FFI::MemoryPointer.from_string(str) })

			# Prepare the ENV parameter.
			env = FFI::MemoryPointer.new(:pointer, ENV.size)
			env.write_array_of_pointer(ENV.to_a.map { |pair| FFI::MemoryPointer.from_string(pair[0] + '=' + pair[1]) })

			GenericValue.new(Bindings.run_function_as_main(@ptr, fun, args.length, argv, env))
		end
		alias :run_main :run_function_as_main

		# @return [TargetData] Information about the target architecture for this execution engine.
		def target_data
			TargetData.new(Bindings.get_execution_engine_target_data(@ptr))
		end
	end

	# An execution engine that interprets the given code.
	class Interpreter < ExecutionEngine

		# Create a new interpreter.
		#
		# @param [Module] mod Module to be executed.
		def initialize(mod)
			super(mod) do |ptr, error|
				Bindings.create_interpreter_for_module(ptr, mod, error)
			end
		end
	end

	# An execution engine that compiles the given code when needed.
	class JITCompiler < ExecutionEngine

		# Create a new just-in-time compiler.
		#
		# @param [Module]	mod		Module to be executed.
		# @param [1, 2, 3]	opt_level	Optimization level; determines how much optimization is done during execution.
		def initialize(mod, opt_level = 3)
			super(mod) do |ptr, error|
				Bindings.create_jit_compiler_for_module(ptr, mod, opt_level, error)
			end
		end
	end

	# Options for initializing a {MCJITCompiler}.
	class MCJITCompilerOptions < RLTK::CG::Bindings::MCJITCompilerOptions

		# Create an object representing MCJIT compiler options.
		#
		# @param [Integer]                        opt_level              Optimization level
		# @param [Symbol from _enum_code_model_]  code_model             JIT compilation code model
		# @param [Boolean]                        no_frame_pointer_elim  Disable frame pointer elimination
		# @param [Boolean]                        enable_fast_i_sel      Turn on fast instruction selection
		def initialize(opt_level = 0, code_model = :jit_default, no_frame_pointer_elim = false,
		               enable_fast_i_sel = true)

			Bindings.initialize_mcjit_compiler_options(self.to_ptr, self.class.size)

			super(opt_level, code_model, no_frame_pointer_elim.to_i, enable_fast_i_sel.to_i, nil)
		end
	end

	# The new LLVM JIT execution engine.
	class MCJITCompiler < ExecutionEngine

		# Create a new MC just-in-time-compiler.
		#
		# @see http://llvm.org/docs/MCJITDesignAndImplementation.html
		# @see http://blog.llvm.org/2013/07/using-mcjit-with-kaleidoscope-tutorial.html
		#
		# @param [Module]                mod      Module to be executed
		# @param [MCJITCompilerOptions]  options  Options used to create the MCJIT
		def initialize(mod, options = MCJITCompilerOptions.new)
			super(mod) do |ptr, error|
				Bindings.create_mcjit_compiler_for_module(ptr, mod, options, MCJITCompilerOptions.size, error)
			end
		end
	end
end
