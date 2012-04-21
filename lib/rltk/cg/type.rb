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
	module TypeChecker
		def check_type(type, type_class = Type)
			if type.is_a?(type_class)
				type
			else
				raise 'The type parameter must be an instance of the RLTK::CG::Type class.'
			end
		end
	end
	
	class Type < BindingClass
		include TypeChecker
		
		# FIXME Hopefully this can be removed at some point.
		def self.from_ptr(ptr)
			case Bindings.get_type_kind(ptr)
			when :array		then ArrayType.new(ptr)
			when :double		then DoubleType.new
			when :float		then FloatType.new
			when :function		then FunctionType.new(ptr)
			when :fp128		then FP128Type.new
			when :integer		then IntType.new
			when :label		then LabelType.new
			when :metadata		then raise "Can't generate a Type object for objects of type Metadata."
			when :pointer		then PointerType.new(ptr)
			when :ppc_fp128	then PPCFP128Type.new
			when :struct		then StructType.new(ptr)
			when :vector		then VectorType.new(ptr)
			when :void		then VoidType.new
			when :x86_fp80		then X86FP80Type.new
			when :x86_mmx		then X86MMXType.new
			end
		end
		
		def initialize(context = nil)
			bname = Bindings.get_bname(self.class.name.split('::').last)
			
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
		
		def initialize(type, size_or_address_space = 0)
			@element_type	= check_type(type)
			@ptr			= Bindings.send(Bindings.get_bname(self.class.name.split('::').last), type, size_or_address_space)
		end
	end
	
	class ArrayType	< AggregateType; end
	class PointerType	< AggregateType; end
	class VectorType	< AggregateType; end
	
	class FunctionType < Type
		attr_reader :return_type
		attr_reader :arg_types
		
		def initialize(return_type, arg_types, varargs = false)
			# Check the types of the return_type value and the arg_types
			# contents.
			raise 'The return_type parameter must be an instance of the RLTK::CG::Type class.' if not return_type.is_a?(Type)
			
			if not arg_types.inject(true) { |memo, o| memo and o.is_a?(Type) }
				raise 'The elements of the arg_types parameter must be instances of the RLTK::CG::Type class.'
			end
			
			@return_type	= return_type
			@arg_types	= arg_types.clone.freeze
			
			arg_types_ptr = FFI::MemoryPointer.new(FFI.type_size(:pointer) * arg_types.length)
			arg_types_ptr.write_array_of_pointer(arg_types)
			
			@ptr = Bindings.function_type(result_type, arg_types_ptr, arg_types.length, varargs.to_i)
		end
	end
	
	class StructType < Type
		def initialize(el_types, packed = false, name = nil, context = nil)
			# Check the types of the elements of the el_types parameter.
			if not el_types.inject(true) { |memo, o| memo and o.is_a?(Type) }
				raise 'The elements of the el_types parameter must be instances of the RLTK::CG::Type class.'
			end
			
			el_types_pointer = FFI::MemoryPointer.new(FFI.type_size(:ponter) * el_types.length)
			el_types_ptr.write_array_of_pointer(el_types)
			
			@ptr =
			if name
				raise 'The name parameter must be an instance of the String class.' if not name.instance_of?(String)
				
				returning Bindings.struct_create_named(Context.global, name) do |ptr|
					Bindings.struct_set_body(ptr, elt_types_ptr, elt_types.size, is_packed.to_i) unless el_types.empty?
				end
				
			elsif context
				raise 'The context parameter must be an instance of the RLTK::CG::Context class.' if not context.is_a?(Context)
				
				Bindings.struct_type_in_context(context, el_types_ptr, el_types.length, is_packed.to_i)
				
			else
				Bindings.struct_type(el_types_ptr, el_types.length, is_packed.to_i)
			end
		end
	end
end
