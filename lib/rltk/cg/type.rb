# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/18
# Description:	This file defines the various LLVM Types.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/util/abstract_class'
require 'rltk/cg/bindings'
require 'rltk/cg/context'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	def check_cg_type(o, type = Type, blame = 'type', strict = false)
		if o.is_a?(Class)
			type_ok = if strict then o == type else o.subclass_of?(type) end 
			
			if type_ok
				if o.includes_module?(Singleton)
					o.instance
				else
					raise "The #{o.name} class (passed as parameter #{blame}) must be instantiated directly."
				end
			else
				raise "The #{o.name} class (passed as parameter #{blame} does not inherit from the #{type.name} class." 
			end
		else
			check_type(o, type, blame, strict)
		end
	end
	
	def check_cg_array_type(array, type = Type, blame = 'el_types', strict = false)
		array.map do |o|
			if o.is_a?(Class)
				type_ok = if strict then o == type else o.subclass_of?(type) end
				
				if type_ok
					if o.includes_module?(Singletone)
						o.instance
					else
						raise "The #{o.name} class (passed in parameter #{blame}) must be instantiated directly."
					end
				else
					raise "The #{o.name} class (passed in parameter #{blame}) does not inherit from the #{type.name} class."
				end
				
			else
				type_ok = if strict then o.instance_of(type) else o.is_a?(type) end
				
				if type_ok
					o
				else
					raise "Parameter #{blame} must contain instances of the #{type.name} class."
				end
			end
		end
	end
	
	class Type < BindingClass
		include AbstractClass
		
		def initialize(context = nil)
			bname = Bindings.get_bname(self.class.short_name)
			
			@ptr =
			if context
				Bindings.send(bname)
			else
				Bindings.send((bname.to_s + '_in_context').to_sym, context)
			end
		end
		
		def allignment
			Bindings.align_of(@ptr)
		end
		
		def context
			Context.new(Bindings.get_type_context(@ptr))
		end
		
		def hash
			@ptr.address.hash
		end
		
		def size
			Bindings.size_of(@ptr)
		end
	end
	
	class NumberType < Type
		include AbstractClass
		
		def self.value_class
			begin
				RLTK::CG.const_get(self.name.match(/::(.+)Type$/).captures.last.to_sym)
				
			rescue
				raise "#{self.name} has no value class."
			end
		end
		
		def value_class
			self.class.value_class
		end
	end
	
	# Never instantiate this class.
	class BasicIntType < NumberType
		include AbstractClass
		
		def width
			@width ||= Bindings.get_int_type_width(@ptr)
		end
	end
	
	class IntType < BasicIntType
		def initialize(width, context = nil)
			if width > 0
				@ptr =
				if context
					Bindings.get_int_type_in_context(width, context)
				else
					Bidnings.get_int_type(width)
				end
			else
				raise 'The width parameter must be greater then 0.'
			end
		end
		
		def value_class
			raise 'The RLKT::CG::IntType class has no value class.'
		end
	end
	
	class SimpleIntType < BasicIntType
		include AbstractClass
		include Singleton
	end
	
	class RealType < NumberType
		include AbstractClass
		include Singleton
	end
	
	class SimpleType < Type
		include AbstractClass
		include Singleton
	end
	
	class Int1Type		< SimpleIntType; end
	class Int8Type		< SimpleIntType; end
	class Int16Type	< SimpleIntType; end
	class Int32Type	< SimpleIntType; end
	class Int64Type	< SimpleIntType; end
	
	NativeIntType = const_get("Int#{FFI.type_size(:int) * 8}Type")
	
	class DoubleType	< RealType; end
	class FloatType	< RealType; end
	class FP128Type	< RealType; end
	class PPCFP128Type	< RealType; end
	class X86FP80Type	< RealType; end
	
	class X86MMXType	< SimpleType; end
	
	class VoidType		< SimpleType; end
	class LabelType	< SimpleType; end
	
	class AggregateType < Type
		include AbstractClass
		
		attr_reader :element_type
		
		def initialize(overloaded, size_or_address_space = 0)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded, nil
			else
				@element_type	= check_cg_type(overloaded, Type, 'overloaded')
				bname		= Bindings.get_bname(self.class.short_name)
				
				Bindings.send(bname, @element_type, size_or_address_space)
			end
		end
	end
	
	class ArrayType	< AggregateType; end
	class PointerType	< AggregateType; end
	class VectorType	< AggregateType; end
	
	class FunctionType < Type
		attr_reader :arg_types
		attr_reader :return_type
		
		def initialize(overloaded, arg_types = nil, varargs = false)
			@ptr =
			case overloaded
			when FFIP::Pointer
				overloaded
			else
				@return_type	= check_cg_type(overloaded, Type, 'return_type')
				@arg_types	= check_cg_array_type(arg_types, Type, 'arg_types').freeze
				
				FFI::MemoryPointer.new(FFI.type_size(:pointer) * @arg_types.length) do |arg_types_ptr|
					arg_types_ptr.write_array_of_pointer(@arg_types)
					
					Bindings.function_type(@return_type, arg_types_ptr, @arg_types.length, varargs.to_i)
				end
			end
		end
	end
	
	class StructType < Type
		attr_reader :element_types
		
		def initialize(overloaded, packed = false, name = nil, context = nil)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				# Check the types of the elements of the overloaded parameter.
				@element_types = check_cg_array_type(overloaded, Type, 'overloaded')
				
				FFI::MemoryPointer.new(FFI.type_size(:pointer) * @element_types.length) do |el_types_pointer|
					el_types_ptr.write_array_of_pointer(@element_types)
				
					if name
						check_type(name, String, 'name')
				
						returning Bindings.struct_create_named(Context.global, name) do |ptr|
							Bindings.struct_set_body(ptr, elt_types_ptr, @element_types.length, is_packed.to_i) unless @element_types.empty?
						end
				
					elsif context
						check_type(context, Context, 'context')
				
						Bindings.struct_type_in_context(context, el_types_ptr, @element_types.length, is_packed.to_i)
				
					else
						Bindings.struct_type(el_types_ptr, @element_types.length, is_packed.to_i)
					end
				end
			end
		end
	end
end
