# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the ExecutionEngine class, along with its
#			subclasses.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/util/abstract_class'
require 'rltk/cg/bindings'
require 'rltk/cg/pass_manager'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
	# The ExecutionEngine class and its subclasses execute code from the
	# provided module, as well as providing a {PassManager} and
	# {FunctionPassManager} for optimizing modules.
	#
	# @abstract Implemented by {Interpreter} and {JITCompiler}.
	class ExecutionEngine
		include AbstractClass
		include BindingClass
		
		# @return [Module]
		attr_reader :module
		
		# Create a new execution engine.
		#
		# @param [Module]	mod		Module to be executed.
		# @param [Proc]	block	Block used by subclass constructors.  Don't use this parameter.
		#
		# @raise [RuntimeError] An error is raised if something went horribly wrong inside LLVM during the creation of this engine.
		def initialize(mod, &block)
			block = Proc.new { |ptr, error| Bindings.create_execution_engine_for_module(ptr, mod, error) } if block == nil
			
			ptr		= FFI::MemoryPointer.new(:pointer)
			error	= FFI::MemoryPointer.new(:pointer)
			status	= block.call(ptr, error)
			
			if status.zero?
				@ptr		= ptr.read_pointer
				@module	= mod
		
			else
				errorp  = error.read_pointer
				message = errorp.null? ? 'Unknown' : errorp.read_string
		
				error.autorelease = false
		
				Bindings.dispose_message(error)
		
				raise "Error creating execution engine: #{message}"
			end
		end
		
		# Frees the resources used by LLVM for this execution engine..
		#
		# @return [void]
		def dispose
			if @ptr
				Bindings.dispose_execution_engine(@ptr)
				
				@ptr = nil
			end
		end
		
		# @return [FunctionPassManager] Function pass manager for this engine.
		def function_pass_manager
			@function_pass_manager ||= FunctionPassManager.new(self, @module)
		end
		alias :fpm :function_pass_manager
		
		# @return [PassManager] Pass manager for this engine.
		def pass_manager
			@pass_manager ||= PassManager.new(self, @module)
		end
		alias :pm :pass_manager
		
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
			new_values = Array.new
			
			new_args =
			fun.params.zip(args).map do |param, arg|
				if arg.is_a?(GenericValue)
					arg
					
				else
					returning(GenericValue.new(arg)) { |val| new_values << val }
				end
			end
			
			args_ptr = FFI::MemoryPointer.new(:pointer, args.length)
			args_ptr.write_array_of_pointer(new_args)
			
			returning(GenericValue.new(Bindings.run_function(@ptr, fun, args.length, args_ptr))) do
				new_values.each { |val| val.dispose }
			end
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
end
