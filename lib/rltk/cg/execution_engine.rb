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

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class ExecutionEngine
		def initialize(mod, &block)
			block = Proc.new { Bindings.create_execution_engine_for_module(ptr, mod, error) } if block == nil
			
			ptr   = FFI::MemoryPointer.new(FFI.type_size(:pointer))
			error = FFI::MemoryPointer.new(FFI.type_size(:pointer))
			
			status = block.call
			
			if status.zero?
				@ptr = ptr.read_pointer
				
			else
				errorp  = error.read_pointer
				message = errorp.null? ? 'Unknown' : errorp.read_string
				
				error.autorelease = false
				
				Bindings.dispose_message(error)
				
				raise "Error creating execution engine: #{message}"
			end
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
	end
end
