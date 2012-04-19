# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the ExecutionEngine class, along with its
#			subclasses.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/pass_manager'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class ExecutionEngine < BindingClass
		attr_reader :module
		
		def initialize(mod, &block)
			block = Proc.new { Bindings.create_execution_engine_for_module(ptr, mod, error) } if block == nil
			
			ptr   = FFI::MemoryPointer.new(FFI.type_size(:pointer))
			error = FFI::MemoryPointer.new(FFI.type_size(:pointer))
			
			status = block.call(ptr, error)
			
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
		
		def dispose
			if @ptr
				Bindings.dispose_execution_engine(@ptr)
				
				@ptr = nil
			end
		end
		
		def function_pass_manager
			@function_pass_manager ||= FunctionPassManager.new(self, @module)
		end
		alias :fpm :function_pass_manager
		
		def pass_manager
			@pass_manager ||= PassManager.new(self)
		end
		alias :pm :pass_manager
		
		def pointer_to_global(global)
			Bindings.get_pointer_to_global(@ptr, global)
		end
	end
	
	class Interpreter < ExecutionEngine
		def initialize(mod)
			super do |ptr, error|
				Bindings.create_interpreter_for_module(ptr, mod, error)
			end
		end
	end
	
	class JITCompiler < ExecutionEngine
		def initialize(mod, opt_level = 3)
			super do |ptr, error|
				Bindings.create_jit_compiler_for_module(ptr, mod, opt_level, error)
			end
		end
		
		def run_function(fun, *args)
			FFI::MemoryPointer.new(FFI.type_size(:pointer) * args.length) do |args_ptr|
				new_values = Array.new
				
				new_args =
				fun.params.zip(args).map do |param, arg|
					if arg.is_a?(GenericValue)
						arg
						
					else
						returning(GenericValue.new(arg)) { |val| new_values << val }
					end
				end
				
				args_ptr.write_array_of_pointer(new_args)
				
				returning(GenericValue.new(Bindings.run_function(@ptr, fun, args.length, args_ptr))) do
					new_values.each { |val| val.dispose }
				end
			end
		end
	end
end
