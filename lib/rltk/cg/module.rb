# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Module class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Module
		include BindingClass
		
		def self.read_bitcode(overloaded)
			buffer = if overloaded.is_a?(MemoryBuffer) then overloaded else MemoryBuffer.new(overloaded) end
			
			FFI::MemoryPonter.new(:pointer) do |mod_ptr|
				FFI::MemoryPointer.new(:pointer) do |msg_ptr|
					status = Bindings.parse_bitcode(buffer, mod_ptr, msg_ptr)
					
					raise msg_ptr.get_pointer(0).get_string(0) if status != 0
					
					Module.new(mod_ptr.get_pointer(0))
				end
			end
		end
		
		def initialize(overloaded, context = nil)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
				
			when String
				if context
					Bindings.module_create_with_name_in_context(name, context)
				else
					Bindings.module_create_with_name(name)
				end
			end
		end
		
		def context
			Context.new(Bindings.get_module_context(@ptr))
		end
		
		def dispose
			if @ptr
				Bindings.dispose_module(@ptr)
				
				@ptr = nil
			end
		end
		
		def dump
			Bindings.dump_module(@ptr)
		end
		
		def functions
			@functions ||= FunctionCollection.new(self)
		end
		alias :funs :functions
		
		def globals
			@globals ||= GlobalCollection.new(self)
		end
		
		def write_bitecode(overloaded)
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
		
		class FunctionCollection
			include Enumerable
			
			def initialize(mod)
				@module = mod
			end
			
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |fun| if fun then self.next(fun) else break end }
				end
			end
			
			def add(name, *type_info, &block)
				Function.new(@module, name, *type_info)
			end
			
			def delete(fun)
				Bindings.delete_function(fun)
			end
			
			def each
				fun = self.first
				
				while fun
					yield fun
					fun = self.next(fun)
				end
			end
			
			def first
				Function.new(Bindings.get_first_function(@module))
			end
			
			def last
				Function.new(Bindings.get_last_function(@module))
			end
			
			def named(name)
				Function.new(Bindings.get_named_function(@module, name))
			end
			
			def next(fun)
				Function.new(Bindings.get_next_function(fun))
			end
			
			def previous(fun)
				Function.new(Bindings.get_previous_function(fun))
			end
		end
		
		class GlobalCollection
			include Enumerable
			
			def initialize(mod)
				@module = mod
			end
			
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |global| if global then self.next(global) else break end }
				end
			end
			
			def add(type, name)
				GlobalVariable.new(Bindings.add_global(@module, type, name))
			end
			
			def delete(global)
				Bindings.delete_global(global)
			end
			
			def each
				global = self.first
				
				while global
					yield global
					global = self.next(global)
				end
			end
			
			def first
				GlobalValue.new(Bindings.get_first_global(@module))
			end
			
			def last
				GlobalValue.new(Bindings.get_last_global(@module))
			end
			
			def named(name)
				GlobalValue.new(Bindings.get_named_global(@module, name))
			end
			
			def next(global)
				GlobalValue.new(Bindings.get_next_global(global))
			end
			
			def previous(global)
				GlobalValue.new(Bindings.get_previous_global(global))
			end
		end
	end
end
