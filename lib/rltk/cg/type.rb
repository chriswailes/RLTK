# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/18
# Description:	This file defines the various LLVM Types.

############
# Requires #
############

# Standard Library
require 'singleton'

# Gems
require 'filigree/abstract_class'

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/context'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# The Type class and its sub-classes are used to describe the size and
	# structure of various data objects inside LLVM and how different
	# operations interact with them.  When instantiating objects of the
	# {Value} class you will often need to pass in some type information.
	#
	# @abstract Root of the type class hierarchy.
	class Type
		include BindingClass
		include Filigree::AbstractClass

		# Instantiate a Type object from a pointer.  This function is used
		# internally, and as a library user you should never have to call it.
		#
		# @param [FFI::Pointer] ptr
		#
		# @return [Type] A object of type Type or one of its sub-classes.
		def self.from_ptr(ptr)
			case Bindings.get_type_kind(ptr)
			when :array		then ArrayType.new(ptr)
			when :half          then HalfType.new
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

		# The default constructor for Type objects.
		#
		# @param [Context, nil] context An optional context in which to create the type.
		def initialize(context = nil)
			bname = Bindings.get_bname(self.class.short_name)

			@ptr =
			if context
				Bindings.send((bname.to_s + '_in_context').to_sym, check_type(context, Context, 'context'))
			else
				Bindings.send(bname)
			end
		end

		# @return [NativeInt] Alignment of the type.
		def allignment
			NativeInt.new(Bindings.align_of(@ptr))
		end

		# @return [Context] Context in which this type was created.
		def context
			Context.new(Bindings.get_type_context(@ptr))
		end

		# Dump a string representation of the type to stdout.
		#
		# @return [void]
		def dump
			Bindings.dump_type(@ptr)
		end

		# @return [Fixnum] Hashed value of the pointer representing this type.
		def hash
			@ptr.address.hash
		end

		# @see Bindings._enum_type_kind_
		#
		# @return [Symbol] The *kind* of this type.
		def kind
			Bindings.get_type_kind(@ptr)
		end

		# @return [NativeInt] Size of objects of this type.
		def size
			Int64.new(Bindings.size_of(@ptr))
		end

		# @return [String]  LLVM IR representation of the type
		def to_s
			Bindings.print_type_to_string(@ptr)
		end
	end

	# All types that are used to represent numbers inherit from this class.
	#
	# @abstract
	class NumberType < Type
		include Filigree::AbstractClass

		# @return [Value] The corresponding Value sub-class that is used to represent values of this type.
		def self.value_class
			begin
				@value_class ||=
				RLTK::CG.const_get(self.name.match(/::(.+)Type$/).captures.last.to_sym)

			rescue
				raise "#{self.name} has no value class."
			end
		end

		# @return [Value] The corresponding Value sub-class that is used to represent values of this type.
		def value_class
			self.class.value_class
		end
	end

	# All types that represent integers of a given width inherit from this class.
	#
	# @abstract
	class BasicIntType < NumberType
		include Filigree::AbstractClass

		# @return [Integer] Number of bits used to represent an integer type.
		def width
			@width ||= Bindings.get_int_type_width(@ptr)
		end
	end

	# An integer of an arbitrary width.
	class IntType < BasicIntType
		# @param [Integer] width		Width of new integer type.
		# @param [Context] context	Context in which to create the type.
		#
		# @raise [RuntimeError] Raises an error when width is <= 0.
		def initialize(width, context = nil)
			if width > 0
				@ptr =
				if context
					Bindings.get_int_type_in_context(width, check_type(context, Context, 'context'))
				else
					Bidnings.get_int_type(width)
				end
			else
				raise 'The width parameter must be greater then 0.'
			end
		end

		# Overrides {NumberType#value_class}.
		#
		# @raise [RuntimeError] This function has no meaning in this class.
		def value_class
			raise 'The RLKT::CG::IntType class has no value class.'
		end
	end

	# A class inherited by singleton integer type classes.
	#
	# @abstract
	class SimpleIntType < BasicIntType
		include Filigree::AbstractClass
		include Singleton
	end

	# A class inherited by all types representing floats.
	#
	# @abstract
	class RealType < NumberType
		include Filigree::AbstractClass
		include Singleton
	end

	# A class inherited by non-number singleton type classes.
	#
	# @abstract
	class SimpleType < Type
		include Filigree::AbstractClass
		include Singleton
	end

	# 1 bit integer type.  Often used to represent Boolean values.
	class Int1Type  < SimpleIntType; end
	# 8 bit (1 byte) integer type.
	class Int8Type  < SimpleIntType; end
	# 16 bit (2 byte) integer type.
	class Int16Type < SimpleIntType; end
	# 32 bit (4 byte) integer type.
	class Int32Type < SimpleIntType; end
	# 64 bit (8 byte) integer type.
	class Int64Type < SimpleIntType; end

	# Integer the same size as a native pointer.
	class IntPtr < SimpleIntType
		# Create an integer that is the same size as a pointer on the target
		# machine.  Additionally, an address space and a context may be
		# provided.
		#
		# @param [TargetData]  target_data  Data on compilation target
		# @param [Integer]     addr_space   Target address space
		# @param [Context]     context      Context in which to get the type
		def initialize(target_data, addr_space = nil, context = nil)
			call = 'int_type'
			args = [target_data]

			if addr_space
				call += '_for_as'
				args << addr_space
			end

			if context
				call += '_in_context'
				args << context
			end

			Bindings.send(call.to_s, *args)
		end
	end

	# The native integer type on the current (not the target) platform.
	NativeIntType = RLTK::CG.const_get("Int#{FFI.type_size(:int) * 8}Type")

	# A 16-bit floating point number type.
	class HalfType     < RealType; end
	# A double precision floating point number type.
	class DoubleType   < RealType; end
	# A single precision floating point number type.
	class FloatType    < RealType; end
	# A 128 bit (16 byte) floating point number type.
	class FP128Type    < RealType; end
	# A 128 bit (16 byte) floating point number type for the PPC architecture.
	class PPCFP128Type < RealType; end
	# A 80 bit (10 byte) floating point number type for the x86 architecture.
	class X86FP80Type  < RealType; end

	# A type for x86 MMX instructions.
	class X86MMXType   < SimpleType; end

	# A type used in representing void pointers and functions that return no values.
	class VoidType     < SimpleType; end
	# A type used to represent labels in LLVM IR.
	class LabelType    < SimpleType; end

	# The common ancestor for array, pointer, and struct types.
	#
	# @abstract
	class AggregateType < Type
		include Filigree::AbstractClass
	end

	# {ArrayType} and {PointerType} inherit from this class so they can share
	# a constructor.
	#
	# @abstract
	class SimpleAggregateType < AggregateType
		include Filigree::AbstractClass

		# Used to initialize {ArrayType ArrayTypes} and {PointerType PointerTypes}.
		#
		# @param [FFI::Pointer, Type] overloaded Pointer to an existing aggregate type or a Type object that
		#   describes the objects that will be stored in an aggregate type.
		def initialize(overloaded, size_or_address_space = 0)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				@element_type	= check_cg_type(overloaded, Type, 'overloaded')
				bname		= Bindings.get_bname(self.class.short_name)

				Bindings.send(bname, @element_type, size_or_address_space)
			end
		end

		# @return [Type] Type of objects stored inside this aggregate.
		def element_type
			@element_type ||= Type.from_ptr(Bindings.get_element_type(@ptr))
		end
	end

	# A Type describing an array that holds objects of a single given type.
	class ArrayType < SimpleAggregateType
		# @return [Integer] Number of elements in this array type.
		def size
			@length ||= Bindings.get_array_length(@ptr)
		end
		alias :length :size
	end

	# A Type describing a pointer to another type.
	class PointerType < SimpleAggregateType
		# @return [Integer] Address space of this pointer.
		def address_space
			@address_space ||= Bindings.get_pointer_address_space(@ptr)
		end
	end

	# A type used to represent vector operations (SIMD).  This is NOT an
	# aggregate type.
	class VectorType < Type
		# Create a new vector type from a pointer or a type.
		#
		# @param [FFI::Pointer, Type]	overloaded	Pointer to existing vector type or Type of object stored in the vector.
		# @param [Integer]			size			Number of objects in this vector type.
		def initialize(overloaded, size = 0)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				@element_type	= check_cg_type(overloaded, Type, 'overloaded')
				bname		= Bindings.get_bname(self.class.short_name)

				Bindings.send(bname, @element_type, size)
			end
		end

		# @return [Type] Type of object stored inside this vector.
		def element_type
			@element_type ||= Type.from_ptr(Bindings.get_element_type(@ptr))
		end

		# @return [Integer] Number of objects in this vector type.
		def size
			Bindings.get_vector_size(@ptr)
		end
		alias :length :size
	end

	# A type representing the return an argument types for a function.
	class FunctionType < Type
		# @return [Array<Type>] Types of this function type's arguments.
		attr_reader :arg_types

		# Create a new function type from a pointer or description of the
		# return type and argument types.
		#
		# @param [FFI::Pointer, Type]	overloaded	Pointer to existing function type or the return type.
		# @param [Array<Type>]		arg_types		Types of the function's arguments.
		# @param [Boolean]			varargs		Weather or not this function has varargs.
		def initialize(overloaded, arg_types = nil, varargs = false)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				@return_type	= check_cg_type(overloaded, Type, 'return_type')
				@arg_types	= check_cg_array_type(arg_types, Type, 'arg_types').freeze

				arg_types_ptr = FFI::MemoryPointer.new(:pointer, @arg_types.length)
				arg_types_ptr.write_array_of_pointer(@arg_types)

				Bindings.function_type(@return_type, arg_types_ptr, @arg_types.length, varargs.to_i)
			end
		end

		# @return [Array<Type>] Types of this function type's arguments.
		def argument_types
			@arg_types ||=
			begin
				num_elements = Bindings.count_param_types(@ptr)

				ret_ptr = FFI::MemoryPointer.new(:pointer)
				Bindings.get_param_types(@ptr, ret_ptr)

				types_ptr = ret_ptr.get_pointer(0)

				types_ptr.get_array_of_pointer(0, num_elements).map { |ptr| Type.from_ptr(ptr) }
			end
		end
		alias :arg_types :argument_types

		# @return [Type] The return type of this function type.
		def return_type
			@return_type ||= Type.from_ptr(Bindings.get_return_type(@ptr))
		end
	end

	# A type for representing an arbitrary collection of types.
	class StructType < AggregateType
		# Create a new struct type.
		#
		# @param [FFI::Pointer, Array<Type>]	overloaded	Pointer to an existing struct type or an array of types in the struct.
		# @param [String, nil]				name			Name of the new struct type in LLVM IR.
		# @param [Boolean]					packed		Are the types packed already, or should they be re-arranged to save space?
		# @param [Context, nil]				context		Context in which to create this new type.
		def initialize(overloaded, name = nil, packed = false, context = nil)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				# Check the types of the elements of the overloaded parameter.
				@element_types = check_cg_array_type(overloaded, Type, 'overloaded')

				el_types_ptr = FFI::MemoryPointer.new(:pointer, @element_types.length)
				el_types_ptr.write_array_of_pointer(@element_types)

				if name
					@name = check_type(name, String, 'name')

					Bindings.struct_create_named(Context.global, @name).tap do |ptr|
						Bindings.struct_set_body(ptr, el_types_ptr, @element_types.length, packed.to_i) unless @element_types.empty?
					end

				elsif context
					check_type(context, Context, 'context')

					Bindings.struct_type_in_context(context, el_types_ptr, @element_types.length, is_packed.to_i)

				else
					Bindings.struct_type(el_types_ptr, @element_types.length, packed.to_i)
				end
			end
		end

		# @return [Array<Type>] Array of the types in this struct type.
		def element_types
			@element_types ||=
			begin
				num_elements = Bindings.count_struct_element_types(@ptr)

				ret_ptr = FFI::MemoryPointer.new(:pointer)
				Bindings.get_struct_element_types(@ptr, ret_ptr)

				types_ptr = ret_ptr.get_pointer(0)

				types_ptr.get_array_of_pointer(0, num_elements).map { |ptr| Type.from_ptr(ptr) }
			end
		end

		# Set the types in the body of this struct type.
		#
		# @param [Array<Type>]	el_types	Array of types in the struct.
		# @param [Boolean]		packed	Are the types packed already, or should they be re-arranged to save space?
		#
		# @return [void]
		def element_types=(el_types, packed = false)
			@element_types = check_cg_array_type(el_types, Type, 'el_types')

			el_types_ptr = FFI::MemoryPointer.new(:pointer, @element_types.length)
			el_types_ptr.write_array_of_pointer(@element_types)

			Bindings.struct_set_body(@ptr, el_types_ptr, @element_types.length, packed.to_i)
		end

		# @return [String] Name of the struct type in LLVM IR.
		def name
			@name ||= Bindings.get_struct_name(@ptr)
		end
	end
end

####################
# Helper Functions #
####################

# This helper function checks to make sure that an object is a sub-class of
# {RLTK::CG::Type Type} or an instance of a sub-class of Type.  If a class is
# passed in the *o* parameter it is expected to be a singleton class and will
# be instantiated via the *instance* method.
#
# @param [Type, Class]	o		Object to type check for code generation type.
# @param [Type]		type		Class the object should be an instance (or sub-class) of.
# @param [String]		blame	Variable name to blame for failed type checks.
# @param [Boolean]		strict	Strict or non-strict checking.  Uses `instance_of?` and `is_a?` respectively.
#
# @raise [ArgumentError] An error is raise if a class is passed in parameter *o*
#   that hasn't included the Singleton class, if the class passed in parameter
#   *type* isn't a sub-class of {RLTK::CG::Type Type}, or if the type check
#   fails.
#
# @return [Type] The object *o* or an instance of the class passed in parameter *o*.
def check_cg_type(o, type = RLTK::CG::Type, blame = 'type', strict = false)
	if o.is_a?(Class)
		type_ok = if strict then o == type else o.subclass_of?(type) end

		if type_ok
			if o.includes_module?(Singleton)
				o.instance
			else
				raise ArgumentError, "The #{o.name} class (passed as parameter #{blame}) must be instantiated directly."
			end
		else
			raise ArgumentError, "The #{o.name} class (passed as parameter #{blame} does not inherit from the #{type.name} class."
		end
	else
		check_type(o, type, blame, strict)
	end
end

# This helper function checks to make sure that an array of objects are all
# sub-classses of {RLTK::CG::Type Type} or instances of a sub-class of Type.
# If a class is present in the *array* parameter it is expected to be a
# singleton class and will be instantiated via the *instance* method.
#
# @param [Array<Type, Class>]	array	Array of objects to type check for code generation type.
# @param [Type]			type		Class the objects should be an instance (or sub-class) of.
# @param [String]			blame	Variable name to blame for failed type checks.
# @param [Boolean]			strict	Strict or non-strict checking.  Uses `instance_of?` and `is_a?` respectively.
#
# @raise [ArgumentError] An error is raise if a class is passed in *array* that
#   hasn't included the Singleton class, if the class passed in parameter
#   *type* isn't a sub-class of {RLTK::CG::Type Type}, or if the type check
#   fails.
#
# @return [Array<Type>] An array containing the objects in *array* with any singleton classes replaced by their instances.
def check_cg_array_type(array, type = RLTK::CG::Type, blame = 'el_types', strict = false)
	array.map do |o|
		if o.is_a?(Class)
			type_ok = if strict then o == type else o.subclass_of?(type) end

			if type_ok
				if o.includes_module?(Singleton)
					o.instance
				else
					raise ArgumentError, "The #{o.name} class (passed in parameter #{blame}) must be instantiated directly."
				end
			else
				raise ArgumentError, "The #{o.name} class (passed in parameter #{blame}) does not inherit from the #{type.name} class."
			end

		else
			type_ok = if strict then o.instance_of(type) else o.is_a?(type) end

			if type_ok
				o
			else
				raise ArgumentError, "Parameter #{blame} must contain instances of the #{type.name} class."
			end
		end
	end
end
