# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Module class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/context'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
	# This class represents a collection of functions, constants, and global
	# variables.
	class Module
		include BindingClass
		
		# @!attribute [rw] engine
		#   @return [ExecutionEngine, nil] Execution engine associated with this module.
		attr_accessor :engine
		
		# Load a module from LLVM bitcode.
		#
		# @see MemoryBuffer#initialize
		#
		# @param [MemoryBuffer, FFI::Pointer, String, nil] overloaded Where to read the bitecode from.
		#
		# @return [Module]
		def self.read_bitcode(overloaded)
			buffer = if overloaded.is_a?(MemoryBuffer) then overloaded else MemoryBuffer.new(overloaded) end
			
			mod_ptr = FFI::MemoryPointer.new(:pointer)
			msg_ptr = FFI::MemoryPointer.new(:pointer)
			
			status = Bindings.parse_bitcode(buffer, mod_ptr, msg_ptr)
			
			if status != 0
				raise msg_ptr.get_pointer(0).get_string(0)
			else
				Module.new(mod_ptr.get_pointer(0))
			end
		end
		
		# Create a new LLVM module.
		#
		# @param [FFI::Pointer, String]	overloaded	Pointer to existing module or name of new module. 
		# @param [Context, nil]			context		Optional context in which to create the module.
		# @param [Proc]				block		Block to be executed inside the context of the module.
		def initialize(overloaded, context = nil, &block)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
				
			when String
				if context
					Bindings.module_create_with_name_in_context(overloaded, check_type(context, Context, 'context'))
				else
					Bindings.module_create_with_name(overloaded)
				end
			end
			
			self.instance_exec(&block) if block
		end
		
		# Compile this module to an assembly or object file.
		#
		# @param [String]		file_name		Name of output file.
		# @param [:asm, :object]	mode			Generate assembly or object file?
		# @param [TargetMachine]	target_machine	Machine type to target.
		# @param [0, 1, 2, 3]	opt_level		Optimization level to use during compilation.
		# @param [Boolean]		verify		Verify the module before compilation or not.
		#
		# @return [void]
		def compile(file_name, mode = :object, machine = TargetMachine.host, opt_level = 2, verify = true)
			puts "Module: #{@ptr}"
			puts "Target Machine: #{machine.ptr}"
			puts "Pass Manager: #{self.pm.ptr}"
			
			Bindings.compile_module_to_file(@ptr, machine, self.pm, file_name, mode, opt_level, (!verify).to_i)
		end
		
		# @return [Context] Context in which this module exists.
		def context
			Context.new(Bindings.get_module_context(@ptr))
		end
		
		# Frees the resources used by LLVM for this module.
		#
		# @return [void]
		def dispose
			if @ptr
				Bindings.dispose_module(@ptr)
				
				@ptr = nil
			end
		end
		
		# Print the LLVM IR representation of this value to standard error.
		# This function is the debugging version of the more general purpose
		# {#print} method.
		#
		# @see #print
		#
		# @return [void]
		def dump
			Bindings.dump_module(@ptr)
		end
		
		# @return [FunctionPassManager] Function pass manager for this module.
		def function_pass_manager
			@function_pass_manager ||= FunctionPassManager.new(self)
		end
		alias :fpm :function_pass_manager
		
		# @return [PassManager] Pass manager for this module.
		def pass_manager
			@pass_manager ||= PassManager.new(self)
		end
		alias :pm :pass_manager
		
		# Print the LLVM IR representation of this module to a file.  The
		# file may be specified via a file name (which will be created or
		# truncated) or an object that responds to #fileno.
		#
		# @LLVMECB
		#
		# @param [String, #fileno] io File name or object with a file descriptor to print to.
		#
		# @return [void]
		def print(io = $stdout)
			case io
			when String
				File.open(io, 'w') do |f|
					Bindings.print_module(@ptr, f.fileno)
				end
			else
				Bindings.print_module(@ptr, io.fileno)
			end
		end
		
		# @return [FunctionCollection] Proxy object for inspecting this module's functions.
		def functions
			@functions ||= FunctionCollection.new(self)
		end
		alias :funs :functions
		
		# @return [GlobalCollection] Proxy object for inspecting this module's global values and variables.
		def globals
			@globals ||= GlobalCollection.new(self)
		end
		
		# Set the module's target triple.
		#
		# @param [String] triple Triple value to set.
		#
		# @return [void]
		def target=(triple)
			Bindings.set_target(@ptr, triple)
		end
		
		# Get the module's target triple.
		#
		# @return [String]
		def target
			Bindings.get_target(@ptr)
		end
		
		# Write the module as LLVM bitcode to a file.
		#
		# @param [#path, #fileno, Integer, String] overloaded Where to write the bitcode.
		#
		# @return [Boolean] If the write was successful.
		def write_bitcode(overloaded)
			0 ==
			if overloaded.respond_to?(:path)
				Bindings.write_bitcode_to_file(@ptr, overloaded.path)
				
			elsif overloaded.respond_to?(:fileno)
				Bindings.write_bitcode_to_fd(@ptr, overloaded.fileno, 0, 1)
				
			elsif overloaded.is_a?(Integer)
				Bindings.write_bitcode_to_fd(@ptr, overloaded, 0, 1)
				
			elsif overloaded.is_a?(String)
				Bindings.write_bitcode_to_file(@ptr, overloaded)
			end
		end
		
		# Verify that the module is valid LLVM IR.
		#
		# @return [nil, String] Human-readable description of any invalid constructs if invalid.
		def verify
			do_verification(:return_status)
		end
		
		# Verify that a module is valid LLVM IR and abort the process if it isn't.
		#
		# @return [nil]
		def verify!
			do_verification(:abort_process)
		end
		
		# Helper function for {#verify} and {#verify!}
		def do_verification(action)
			str_ptr	= FFI::MemoryPointer.new(:pointer)
			status	= Bindings.verify_module(@ptr, action, str_ptr)
			
			returning(status == 1 ? str_ptr.read_string : nil) { Bindings.dispose_message(str_ptr.read_pointer) }
		end
		private :do_verification
		
		# This class is used to access a module's {Function Functions}.
		class FunctionCollection
			include Enumerable
			
			# @param [Module] mod Module for which this is a proxy.
			def initialize(mod)
				@module = mod
			end
			
			# Retreive a Function object.
			#
			# @param [String, Symbol, Integer] key Function identifier.  Either the name of the function or its index.
			#
			# @return [Function]
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |fun| if fun then self.next(fun) else break end }
				end
			end
			
			# Add a Function to this module.
			#
			# @param [String]							name		Name of the module in LLVM IR.
			# @param [FunctionType, Array(Type, Array<Type>)]	type_info	FunctionType or Values that will be passed to {FunctionType#initialize}.
			# @param [Proc]							block	Block to be executed inside the context of the function.
			#
			# @return [Function]
			def add(name, *type_info, &block)
				Function.new(@module, name, *type_info, &block)
			end
			
			# Remove a function from the module.
			#
			# @param [Function] fun Function to remove.
			#
			# @return [void]
			def delete(fun)
				Bindings.delete_function(fun)
			end
			
			# An iterator for each function inside this collection.
			#
			# @yieldparam fun [Function]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum(:each) unless block_given?
				
				fun = self.first
				
				while fun
					yield fun
					fun = self.next(fun)
				end
			end
			
			# @return [Function, nil] The module's first function if one has been added.
			def first
				if (ptr = Bindings.get_first_function(@module)).null? then nil else Function.new(ptr) end
			end
			
			# @return [Function, nil] The module's last function if one has been added.
			def last
				if (ptr = Bindings.get_last_function(@module)).null? then nil else Function.new(ptr) end
			end
			
			# @param [String, Symbol] name Name of the desired function.
			#
			# @return [Function, nil] The function with the given name.
			def named(name)
				if (ptr = Bindings.get_named_function(@module, name)).null? then nil else Function.new(ptr) end
			end
			
			# @param [Function] fun Function you want the successor for.
			#
			# @return [Function, nil] Next function in the collection.
			def next(fun)
				if (ptr = Bindings.get_next_function(fun)).null? then nil else Function.new(ptr) end
			end
			
			# @param [Function] fun Function you want the predecessor for.
			#
			# @return [Function, nil] Previous function in the collection.
			def previous(fun)
				if (ptr = Bindings.get_previous_function(fun)).null? then nil else Function.new(ptr) end
			end
		end
		
		# This class is used to access a module's global variables.
		class GlobalCollection
			include Enumerable
			
			# @param [Module] mod Module for which this is a proxy.
			def initialize(mod)
				@module = mod
			end
			
			# Retreive a GlobalVariable object.
			#
			# @param [String, Symbol, Integer] key Global variable identifier.  Either the name of the variable or its index.
			#
			# @return [GlobalVariable]
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |global| if global then self.next(global) else break end }
				end
			end
			
			# Add a global variable to a module.
			#
			# @param [Type]	type	Type of the global variable.
			# @param [String]	name	Name of the global variable in LLVM IR.
			def add(type, name)
				GlobalVariable.new(Bindings.add_global(@module, type, name))
			end
			
			# Remove a global variable from the module.
			#
			# @param [GlobalVariable] global Global variable to remove.
			#
			# @return [void]
			def delete(global)
				Bindings.delete_global(global)
			end
			
			# An iterator for each global variable inside this collection.
			#
			# @yieldparam fun [GlobalVariable]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum(:each) unless block_given?
				
				global = self.first
				
				while global
					yield global
					global = self.next(global)
				end
			end
			
			# @return [GlobalVariable, nil] The module's first global variable if one has been added.
			def first
				if (ptr = Bindings.get_first_global(@module)).null? then nil else GlobalValue.new(ptr) end
			end
			
			# @return [GlobalVariable, nil] The module's last global variable if one has been added.
			def last
				if (ptr = Bindings.get_last_global(@module)).null? then nil else GlobalValue.new(ptr) end
			end
			
			# @param [String, Symbol] name Name of the desired global variable.
			#
			# @return [GlobalVariable, nil] The global variable with the given name.
			def named(name)
				if (ptr = Bindings.get_named_global(@module, name)).null? then nil else GlobalValue.new(ptr) end
			end
			
			# @param [GlobalVariable] global Global variable you want the successor for.
			#
			# @return [GlobalVariable, nil] global Next global variable in the collection.
			def next(global)
				if (ptr = Bindings.get_next_global(global)).null? then nil else GlobalValue.new(ptr) end
			end
			
			# @param [GlobalVariable] global Global variable you want the predecessor for.
			#
			# @return [GlobalVariable, nil] Previous global variable in the collection.
			def previous(global)
				if (ptr = Bindings.get_previous_global(global)).null? then nil else GlobalValue.new(ptr) end
			end
		end
	end
end
