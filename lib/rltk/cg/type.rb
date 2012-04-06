# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/18
# Description:	This file defines the various LLVM Types.

############
# Requires #
############

# Standard Library
require 'singleton'

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/context'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Type < BindingClass
		def ==(other)
			if other.instance_of?(Type)
				other.ptr_eql?(ptr)
			else
				false
			end
		end
		
		def allignment
			Int64.from_ptr(Bindings.align_of(@ptr))
		end
		
		def hash
			@ptr.address.hash
		end
		
		def eql?(other)
			other.class == self.class and self == other
		end
		
		def size
			Int64.from_ptr(Bindings.size_of(@ptr)
		end
		
		protected
		def ptr_eql?(ptr)
			@ptr == ptr
		end
	end
	
	class ContainerType < Type
		attr_reader :element_type
		
		def initialize(element_type)
			if element_type.is_a?(Type)
				@element_type = element_type
				
				@ptr = yield
			else
				raise 'The element_type parameter must be an instance of the RLTK::CG::Type class.'
			end
		end
	end
	
	class ArrayType < ContainerType
		def initialize(element_type, size = 0)
			super(element_type) { Bindings.array_type(@element_type, size) }
		end
	end
	
	class DoubleType < Type
		include Singleton
		
		def initialize
			@ptr = Bindings.double_type
		end
	end
	
	class FloatType < Type
		include Singleton
		
		def initialize
			@ptr = Bindings.float_type
		end
	end
	
	class FunctionType < Type
		attr_reader :return_type
		attr_reader :arg_types
		
		def initialize(return_type, arg_types, varargs = false)
			# Check the types of the return_type value and the arg_types
			# contents.
			if not return_type.is_a?(Type)
				raise 'The return_type parameter must be an instance of the RLTK::CG::Type class.'
			end
			
			if not arg_types.inject(true) { |memo, o| memo and o.is_a?(Type) }
				raise 'The elements of the arg_types parameter must be instances of the RLTK::CG::Type class.'
			end
			
			@return_type	= return_type
			@arg_types	= arg_types.clone.freeze
			
			arg_types_ptr = FFI::MemoryPointer.new(FFI.type_size(:pointer) * arg_types.length)
			arg_types_ptr.write_array_of_pointer(arg_types)
			
			@ptr = Bindings.function_type(result_type, arg_types_ptr, arg_types.length, varargs ? 0 : 1)
		end
	end
	
	class IntType < Type
		include Singleton
		
		def initialize
			@ptr = Bindings.int_type
		end
		
		def width
			Bindings.get_int_type_width(@ptr)
		end
	end
	
	class Int64Type < IntType
		def initialize
			@ptr = Bindings.int64_type
		end
	end
	
	class PointerType < ContainerType
		def initialize(element_type, address_space = 0)
			super(element_type) { Bindings.pointer_type(@element_type, address_space) }
		end
	end
	
	class StructType < Type
		def initialize(el_types, packed, name = nil)
			# Check the types of the elements of the el_types parameter.
			if not el_types.inject(true) { |memeo, o| memo and o.is_a?(Type) }
				raise 'The elements of the el_types parameter must be instances of the RLTK::CG::Type class.'
			end
			
			el_types_pointer = FFI::MemoryPointer.new(FFI.type_size(:ponter) * el_types.length)
			el_types_ptr.write_array_of_pointer(el_types)
			
			if name
				if not name.instance_of?(String)
					raise 'The name parameter must be an instance of the String class.'
				end
				
				@ptr = Bindings.struct_create_named(Context.global, name)
				
				Bindings.struct_set_body(@ptr, elt_types_ptr, elt_types.size, is_packed ? 1 : 0) unless el_types.empty?
			else
				@ptr = Bindings.struct_type(el_types_ptr, el_types.length, is_packed ? 1 : 0)
			end
		end
	end
	
	class VectorType < ContainerType
		def initialize(element_type, size = 0)
			super(element_type) { Bindings.vector_type(@element_type, size) }
		end
	end
	
	class VoidType < Type
		include Singleton
		
		def initialize
			@ptr = Bindings.void_type
		end
	end
end
