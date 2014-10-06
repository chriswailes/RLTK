# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines LLVM Value classes.

############
# Requires #
############

# Gems
require 'filigree/abstract_class'

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/type'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# This class represents LLVM IR "data", including integer and float
	# literals, functions, and constant arrays, structs, and vectors.
	class Value
		include BindingClass

		# Instantiate a Value object from a pointer.  This should never be
		# done by library users, and is only used internally.
		#
		# @param [FFI::Pointer] ptr Pointer to an LLVM value.
		def initialize(ptr)
			@ptr = check_type(ptr, FFI::Pointer, 'ptr')
		end

		# Compare one Value to another.
		#
		# @param [Value] other Another value object.
		#
		# @return [Boolean]
		def ==(other)
			other.is_a?(Value) and @ptr == other.ptr
		end

		# @return [AttrCollection] Proxy object for inspecing a value's attributes.
		def attributes
			@attributes ||= AttrCollection.new(@ptr)
		end
		alias :attrs :attributes

		# Bitcast a value to a given type.
		#
		# @param [Type] type Type to cast to.
		#
		# @return [ConstantExpr]
		def bitcast(type)
			ConstantExpr.new(Bindings.const_bit_cast(@ptr, check_cg_type(type)))
		end

		# @return [Boolean] If this value is a constant.
		def constant?
			Bindings.is_constant(@ptr).to_bool
		end

		# Print the LLVM IR representation of this value to standard error.
		# This function is the debugging version of the more general purpose
		# {#print} method.
		#
		# @see #print
		#
		# @return [void]
		def dump
			Bindings.dump_value(@ptr)
		end

		# @return [Fixnum] Hashed value of the pointer representing this value.
		def hash
			@ptr.address.hash
		end

		# @return [String] Name of this value in LLVM IR.
		def name
			Bindings.get_value_name(@ptr)
		end

		# Set the name of this value in LLVM IR.
		#
		# @param [String] str Name of the value in LLVM IR.
		#
		# @return [String] *str*
		def name=(str)
			str.tap { Bindings.set_value_name(@ptr, check_type(str, String)) }
		end

		# @return [Boolean] If the value is null or not.
		def null?
			Bindings.is_null(@ptr).to_bool
		end

		# @return [String]  LLVM IR representation of this value
		def print
			Bindings.print_value_to_string(@ptr)
		end

		# Truncate a value to a given type.
		#
		# @param [Type] type Type to truncate to.
		#
		# @return [ConstantExpr]
		def trunc(type)
			ConstantExpr.new(Bindings.const_trunc(check_cg_type(type)))
		end

		# Truncate or bitcast a value to the given type as is appropriate.
		#
		# @param [Type] type Type to cast or truncate to.
		#
		# @return [ConstantExpr]
		def trunc_or_bitcast(type)
			ConstantExpr.new(Bindings.const_trunc_or_bit_cast(check_cg_type(type)))
		end

		# @return [Type] Type of this value.
		def type
			@type ||= Type.from_ptr(Bindings.type_of(@ptr))
		end

		# @return [Boolean] If the value is undefined or not.
		def undefined?
			Bindings.is_undef(@ptr).to_bool
		end

		# Zero extend the value to the length of *type*.
		#
		# @param [Type] type Type to extend the value to.
		#
		# @return [ConstantExpr]
		def zextend(type)
			ConstantExpr.new(Bindings.const_z_ext(check_cg_type(type)))
		end

		# Zero extend or bitcast the value to the given type as is appropriate.
		#
		# @param [Type] type Type to cast or extend to.
		#
		# @return [ConstantExpr]
		def zextend_or_bitcast(type)
			ConstantExpr.new(Bindings.const_z_ext_or_bit_cast(check_cg_type(type)))
		end

		# This class is used to access a {Value Value's} attributes.
		class AttrCollection
			@@add_method = :add_attribute
			@@del_method = :remove_attribute

			# @param [Value] value Value for which this is a proxy.
			def initialize(value)
				@attributes	= Array.new
				@value		= value
			end

			# Add the given attribute to a value.
			#
			# @see Bindings._enum_attribute_
			#
			# @param [Symbol] attribute Attribute to add.
			#
			# @return [void]
			def add(attribute)
				if not @attributes.include?(attribute)
					@attributes << attribute
					Bindings.send(@@add_method, @value, attribute)
				end
			end
			alias :'<<' :add

			# Test to see if an attribute has been set on a value.
			#
			# @see Bindings._enum_attribute_
			#
			# @param [Symbol] attribute Attribute to check.
			#
			# @return [Boolean]
			def include?(attribute)
				@attributes.include?(attribute)
			end

			# Remove the given attribute from a value.
			#
			# @see Bindings._enum_attribute_
			#
			# @param [Symbol] attribute Attribute to remove.
			#
			# @return [void]
			def remove(attribute)
				if @attributes.include?(attribute)
					@attributes.delete(attribute)
					Bindings.send(@@del_method, @value, attribute)
				end
			end
			alias :'>>' :remove

			# @return [String] Textual representation of the enabled attributes.
			def to_s
				@attributes.to_s
			end
		end
	end

	# An empty class definition for completeness and future use.
	class Argument < Value; end

	# A base class for a wide variety of classes.
	#
	# @abstract
	class User < Value
		include Filigree::AbstractClass

		# @return [OperandCollection] Proxy object for accessing a value's operands.
		def operands
			@operands ||= OperandCollection.new(self)
		end

		# This class is used to access a {User User's} operands.
		class OperandCollection
			include Enumerable

			# @param [User] user User object for which this is a proxy.
			def initialize(user)
				@user = user
			end

			# Access the operand at the given index.
			#
			# @param [Integer] index
			#
			# @return [Value, nil] Value object representing the operand at *index* if one exists.
			def [](index)
				if (ptr = Bindings.get_operand(@user, index)).null? then nil else Value.new(ptr) end
			end

			# Set the operand at the given index.
			#
			# @param [Integer]	index Index of operand to set.
			# @param [Value]	value Value to set as operand.
			#
			# @return [void]
			def []=(index, value)
				Bindings.set_operand(@user, index, check_type(value, Value, 'value'))
			end

			# An iterator for each operand inside this collection.
			#
			# @yieldparam val [Value]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum(:each) unless block_given?

				self.size.times { |i| yield self[i] }

				self
			end

			# @return [Integer] Number of operands.
			def size
				Bindings.get_num_operands(@user)
			end
		end
	end

	# All classes representing constant values inherit from this class.
	#
	# @abstract
	class Constant < User
		include Filigree::AbstractClass

		# Create a new constant from a pointer or a type.  As a library user
		# you should never pass a pointer in here as that is only used
		# internally.
		#
		# @param [FFI::Pointer, Type] overloaded Pointer to existing constant or a Type.
		def initialize(overloaded)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded

			when Type
				Bindings.send(@@initializer, @type = overloaded)
			else
				raise 'New must be passed either a Type or a FFI::Pointer.'
			end
		end

		# Cast a constant to a given address space
		#
		# @param [Type]  type  Type to cast to
		#
		# @return [ConstantExpr]
		def addr_space_cast(type)
			ConstantExpr.new(Bindings.const_addr_space_cast(@ptr, check_cg_type(type)))
		end

		# Bitcast a constant to a given type.
		#
		# @param [Type]  type  Type to cast to
		#
		# @return [ConstantExpr]
		def bitcast_to(type)
			ConstantExpr.new(Bindings.const_bit_cast(@ptr, check_cg_type(type)))
		end

		# Get a pointer to an element of a constant value.
		#
		# @param [Array<Value>] indices A Ruby array of Value objects representing indicies into the constant value.
		#
		# @return [ConstantExpr] LLVM Value object representing a pointer to a LLVM Value object.
		def get_element_ptr(*indices)
			indicies_ptr = FFI::MemoryPointer.new(:pointer, indices.length)
			indices_ptr.write_array_of_pointer(indices)

			ConstantExpr.new(Bindings.const_gep(@ptr, indices_ptr, indices.length))
		end
		alias :gep :get_element_ptr

		# Get a pointer to an element of a constant value, ensuring that the
		# pointer is within the bounds of the value.
		#
		# @param [Array<Value>] indices A Ruby array of Value objects representing indicies into the constant value.
		#
		# @return [ConstantExpr] LLVM Value object representing a pointer to a LLVM Value object.
		def get_element_ptr_in_bounds(*indices)
			indices_ptr = FFI::MemoryPointer.new(:pointer, indices.length)
			indices_ptr.write_array_of_pointer(indices)

			ConstantExpr.new(Bindings.const_in_bounds_gep(@ptr, indices_ptr, indices.length))
		end
		alias :inbounds_gep :get_element_ptr_in_bounds
	end

	# This class represents a wide range of values returned by various
	# operations.
	class ConstantExpr < Constant
		# Constant expressions can only be instantiated from a pointer, and
		# should never be instantiated by library users.
		#
		# @param [FFI::Pointer] ptr
		def initialize(ptr)
			@ptr = check_type(ptr, FFI::Pointer, 'ptr')
		end
	end

	# A constant null value.
	class ConstantNull < Constant
		@@initializer = :const_null
	end

	# A constant null pointer value.
	class ConstantNullPtr < Constant
		@@initializer = :const_pointer_null
	end

	# A constant undefined value.
	class ConstantUndef < Constant
		@@initializer = :get_undef
	end

	# All constant aggregate values inherit from this class.
	#
	# @abstract
	class ConstantAggregate < Constant
		include Filigree::AbstractClass

		# Extract values from a constant aggregate value.
		#
		# @param [Array<Value>] indices Array of values representing indices into the aggregate.
		#
		# @return [ConstantExpr] Extracted values.
		def extract(*indices)
			indices_ptr = FFI::MemoryPointer.new(:uint, indices.length)
			indices_ptr.write_array_of_uint(indices)

			ConstantExpr.new(Bindings.const_extract_value(@ptr, indices_ptr, indices.length))
		end

		# Insert values into a constant aggregate value.
		#
		# @param [Value]		value	Value to insert.
		# @param [Array<Value>]	indices	Array of values representing indices into the aggregate.
		#
		# @return [ConstantExpr] New aggregate representation with inserted values.
		def insert(value, indices)
			indices_ptr = FFI::MemoryPointer.new(:uint, indices.length)
			indices_ptr.write_array_of_uint(indices)

			ConstantExpr.new(Bindings.const_insert_value(@ptr, value, indices_ptr, inicies.length))
		end
	end

	# A constant array value.
	class ConstantArray < ConstantAggregate
		# Create a new constant array value.
		#
		# @example Using array of values:
		#   ConstantArray.new(Int32Type, [Int32.new(0), Int32.new(1)])
		#
		# @example Using size:
		#    ConstantArray.new(Int32Type, 2) { |i| Int32.new(i) }
		#
		# @yieldparam index [Integer] Index of the value in the array.
		#
		# @param [Type]                   element_type    Type of values in this aggregate.
		# @param [Array<Value>, Integer]  size_or_values  Number of values or array of values.
		# @param [Proc]                   block           Block evaluated if size is specified.
		def initialize(element_type, size_or_values, &block)
			vals_ptr     = make_ptr_to_elements(size_or_values, &block)
			element_type = check_cg_type(element_type, Type, 'element_type')
			@ptr         = Bindings.const_array(element_type, vals_ptr, vals_ptr.size / vals_ptr.type_size)
		end

		def size
			self.type.size
		end
		alias :length :size
	end

	# A sub-class of {ConstantArray} specifically for holding strings.
	class ConstantString < ConstantArray
		# Create a new constant string value.
		#
		# @param [String]		string		Sting to turn into a value.
		# @param [Boolean]		null_terminate	To null terminate the string or not.
		# @param [Context, nil]	context		Context in which to create the value.
		def initialize(string, null_terminate = true, context = nil)
			@type = ArrayType.new(Int8Type)

			@ptr =
			if context
				Bindings.const_string_in_context(check_type(context, Context, 'context'), string, string.length, null_terminate.to_i)
			else
				Bindings.const_string(string, string.length, null_terminate.to_i)
			end
		end
	end

	# A constant struct value.
	class ConstantStruct < ConstantAggregate
		# Create a new constant struct value.
		#
		# @example Using array of values:
		#   ConstantStruct.new([Int32.new(0), Int64.new(1), Int32.new(2), Int64.new(3)])
		#
		# @example Using size:
		#    ConstantStruct.new(4) { |i| if i % 2 == 0 then Int32.new(i) else Int64.new(i) end }
		#
		# @yieldparam index [Integer] Index of the value in the struct.
		#
		# @param [Array<Value>, Integer]	size_or_values	Number of values or array of values.
		# @param [Boolean]				packed		Are the types packed already, or should they be re-arranged to save space?
		# @param [Context, nil]			context		Context in which to create the value.
		# @param [Proc]				block		Block evaluated if size is specified.
		def initialize(size_or_values, packed = false, context = nil, &block)
			vals_ptr = make_ptr_to_elements(size_or_values, &block)

			@ptr =
			if context
				Bindings.const_struct_in_context(check_type(context, Context, 'context'),
				                                 vals_ptr, vals_ptr.size / vals_ptr.type_size, packed.to_i)
			else
				Bindings.const_struct(vals_ptr, vals_ptr.size / vals_ptr.type_size, packed.to_i)
			end
		end
	end

	# A constant vector value used for SIMD instructions.
	class ConstantVector < Constant
		# Create a new constant vector value.
		#
		# @example Using array of values:
		#   ConstantVector.new([Int32.new(0), Int32.new(1)])
		#
		# @example Using size:
		#    ConstantVector.new(2) { |i| Int32.new(i) }
		#
		# @yieldparam index [Integer] Index of the value in the vector.
		#
		# @param [FFI::Pointer, Array<Value>, Integer]	size_or_values	Number of values or array of values.
		# @param [Proc]							block		Block evaluated if size is specified.
		def initialize(size_or_values, &block)
			@ptr =
			if size_or_values.is_a?(FFI::Pointer)
				size_or_values
			else
				vals_ptr = make_ptr_to_elements(size_or_values, &block)

				Bindings.const_vector(vals_ptr, vals_ptr.size / vals_ptr.type_size)
			end
		end

		# @param [Integer] index Index of desired element.
		#
		# @return [ConstantExpr] Extracted element.
		def extract_element(index)
			ConstantExpr.new(Bindings.const_extract_element(@ptr, index))
		end

		# @param [Value]	element	Value to insert into the vector.
		# @param [Integer]	index	Index to insert the value at.
		#
		# @return [ConstantExpr] New vector representation with inserted value.
		def insert_element(element, index)
			ConstantExpr.new(Bindings.const_insert_element(@ptr, element, index))
		end

		# @param [ConstantVector] other	Other vector to shuffle with this one.
		# @param [ConstantVector] mask	Mask to use when shuffling.
		#
		# @return [ConstantVector] New vector formed by shuffling the two vectors together using the mask.
		def shuffle(other, mask)
			ConstantVector.new(Bindings.const_shuffle_vector(@ptr, other, mask))
		end

		def size
			self.type.size
		end
		alias :length :size
	end

	# All number constants inherit from this class.
	#
	# @abstract
	class ConstantNumber < Constant
		include Filigree::AbstractClass

		# @return [Type] The corresponding Type sub-class that is used to represent the type of this value.
		def self.type
			@type ||= RLTK::CG.const_get(self.short_name + 'Type').instance
		end

		# @return [Type] The corresponding Type sub-class that is used to represent the type of this value.
		def type
			self.class.type
		end
	end

	# All integer constants inherit from this class.
	#
	# @abstract
	class ConstantInteger < ConstantNumber
		include Filigree::AbstractClass

		# @return [Boolean] If the integer is signed or not.
		attr_reader :signed

		# The constructor for ConstantInteger's various sub-classes.  This
		# constructor is a bit complicated due to having two overloaded
		# parameters, but once you see the valid combinations it is a bit
		# simpler.
		#
		# @example Constant (signed) integer from Ruby Integer:
		#   Int32.new(128)
		#
		# @example Constant (signed) base 8 integer from Ruby String:
		#   Int32.new('72', 8)
		#
		# @example Constant integer of all 1s:
		#   Int32.new
		#
		# @param [FFI::Pointer, Integer, String, nil]  overloaded0  Pointer to a ConstantInteger, value, or string representing value.
		# @param [Boolean, Integer]                    overloaded1  Signed or unsigned (when overloaded0 is Integer) or base used to
		#    decode string value.
		# @param [Integer]                             size         Optional length of string to use.
		def initialize(overloaded0 = nil, overloaded1 = nil, size = nil)
			@ptr =
			case overloaded0
			when FFI::Pointer
				overloaded0

			when Integer
				@signed = overloaded1 or true

				Bindings.const_int(self.type, overloaded0, @signed.to_i)

			when String
				base = overloaded1 or 10

				if size
					Bindings.const_int_of_string_and_size(self.type, overloaded0, size, base)
				else
					Bindings.const_int_of_string(self.type, overloaded0, base)
				end
			else
				@signed = true

				Bindings.const_all_ones(self.type)
			end
		end

		########
		# Math #
		########

		# Addition

		# Add this value with another value.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def +(rhs)
			self.class.new(Bindings.const_add(@ptr, rhs))
		end

		# Add this value with another value.  Performs no signed wrap
		# addition.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nsw_add(rhs)
			self.class.new(Bindings.const_nsw_add(@ptr, rhs))
		end

		# Add this value with another value.  Performs no unsigned wrap
		# addition.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nuw_add(rhs)
			self.class.new(Bindings.const_nuw_add(@ptr, rhs))
		end

		# Subtraction

		# Subtract a value from this value.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def -(rhs)
			self.class.new(Bindings.const_sub(@ptr, rhs))
		end

		# Subtract a value from this value.  Performs no signed wrap
		# subtraction.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nsw_sub(rhs)
			self.class.new(Bindings.const_nsw_sub(@ptr, rhs))
		end

		# Subtract a value from this value.  Performs no unsigned wrap
		# subtraction.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nuw_sub(rhs)
			self.class.new(Bindings.const_nuw_sub(@ptr, rhs))
		end

		# Multiplication

		# Multiply this value with another value.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def *(rhs)
			self.class.new(Bindings.const_mul(@ptr, rhs))
		end

		# Multiply this value with another value.  Perform no signed wrap
		# multiplication.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nsw_mul(rhs)
			self.class.new(Bindings.const_nsw_mul(@ptr, rhs))
		end

		# Multiply this value with another value.  Perform no unsigned wrap
		# multiplication.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def nuw_mul(rhs)
			self.class.new(Bindings.const_nuw_mul(@ptr, rhs))
		end

		# Division

		# Divide this value by another value.  Uses signed division.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def /(rhs)
			self.class.new(Bindings.const_s_div(@ptr, rhs))
		end

		# Divide this value by another value.  Uses exact signed division.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def extact_sdiv(rhs)
			self.class.new(Bindings.const_extact_s_div(@ptr, rhs))
		end

		# Divide this value by another value.  Uses unsigned division.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def udiv(rhs)
			self.class.new(Bindings.const_u_div(@ptr, rhs))
		end

		# Remainder

		# Modulo this value by another value.  Uses signed modulo.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def %(rhs)
			self.class.new(Bindings.const_s_rem(@ptr, rhs))
		end

		# Modulo this value by another value.  Uses unsigned modulo.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def urem(rhs)
			self.class.new(Bindings.const_u_rem(@ptr, rhs))
		end

		# Negation

		# Negate this value.
		#
		# @return [ConstantInteger] Instance of the same class
		def -@
			self.class.new(Bindings.const_neg(@ptr))
		end

		# Negate this value.  Uses no signed wrap negation.
		#
		# @return [ConstantInteger] Instance of the same class
		def nsw_neg
			self.class.new(Bindings.const_nsw_neg(@ptr))
		end

		# Negate this value.  Uses no unsigned wrap negation.
		#
		# @return [ConstantInteger] Instance of the same class
		def nuw_neg
			self.class.new(Bindings.const_nuw_neg(@ptr))
		end

		######################
		# Bitwise Operations #
		######################

		# A wrapper method around the {#shift_left} and {#shift_right}
		# methods.
		#
		# @param [:left, :right]			dir	The direction to shift.
		# @param [Integer]				bits	Number of bits to shift.
		# @param [:arithmetic, :logical]	mode	Shift mode for right shifts.
		#
		# @return [ConstantInteger] Instance of the same class.
		def shift(dir, bits, mode = :arithmetic)
			case dir
			when :left	then shift_left(bits)
			when :right	then shift_right(bits, mode)
			end
		end

		# Shift the value left a specific number of bits.
		#
		# @param [Integer] bits Number of bits to shift.
		#
		# @return [ConstantInteger] Instance of the same class.
		def shift_left(bits)
			self.class.new(Bindings.const_shl(@ptr, bits))
		end
		alias :shl :shift_left
		alias :<< :shift_left

		# Shift the value right a specific number of bits.
		#
		# @param [Integer]				bits Number of bits to shift.
		# @param [:arithmetic, :logical]	mode Shift mode.
		#
		# @return [ConstantInteger] Instance of the same class.
		def shift_right(bits, mode = :arithmetic)
			case mode
			when :arithmetic	then ashr(bits)
			when :logical		then lshr(bits)
			end
		end

		# Arithmetic right shift.
		#
		# @param [Integer] bits Number of bits to shift.
		#
		# @return [ConstantInteger] Instance of the same class.
		def ashr(bits)
			self.class.new(Bindings.const_a_shr(@ptr, bits))
		end
		alias :>> :ashr

		# Logical right shift.
		#
		# @param [Integer] bits Number of bits to shift.
		#
		# @return [ConstantInteger] Instance of the same class.
		def lshr(bits)
			self.class.new(Bindings.const_l_shr(@ptr, bits))
		end

		# Bitwise AND this value with another.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def and(rhs)
			self.class.new(Bindings.const_and(@ptr, rhs))
		end

		# Bitwise OR this value with another.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def or(rhs)
			self.class.new(Bindings.const_or(@ptr, rhs))
		end

		# Bitwise XOR this value with another.
		#
		# @param [ConstantInteger] rhs
		#
		# @return [ConstantInteger] Instance of the same class.
		def xor(rhs)
			self.class.new(Bindings.const_xor(@ptr, rhs))
		end

		# Bitwise NOT this value.
		#
		# @return [ConstantInteger] Instance of the same class.
		def not
			self.class.new(Bindings.const_not(@ptr))
		end

		#################
		# Miscellaneous #
		#################

		# Cast this constant integer to another number type.
		#
		# @param [NumberType]	type		Desired type to cast to.
		# @param [Boolean]		signed	Is the value signed or not.
		#
		# @return [ConstantNumber] This value as as the given type.
		def cast(type, signed = true)
			type.value_class.new(Bindings.const_int_cast(@ptr, check_cg_type(type, NumberType), signed.to_i))
		end

		# Compare this value to another value.
		#
		# @see Bindings._enum_int_predicate_
		#
		# @param [Symbol]			pred	An integer predicate.
		# @param [ConstantInteger]	rhs	Value to compare to.
		#
		# @return [Int1] Value used to represent a Boolean value.
		def cmp(pred, rhs)
			Int1.new(Bindings.const_i_cmp(pred, @ptr, rhs))
		end

		# Convert this integer to a float.
		#
		# @param [RealType] type Type of float to convert to.
		#
		# @return [ConstantReal] This value as a floating point value of the given type.
		def to_f(type)
			type.value_class.new(Bindings.send(@signed ? :const_si_to_fp : :const_ui_to_fp, @ptr, check_cg_type(type, FloatingPointType)))
		end

		# Get the value of this constant as a signed or unsigned long long.
		#
		# @param [:sign, :zero] extension Extension method.
		#
		# @return [Integer]
		def value(extension = :sign)
			case extension
			when :sign then Bindings.const_int_get_s_ext_value(@ptr)
			when :zero then Bindings.const_int_get_z_ext_value(@ptr)
			end
		end
	end

	# 1 bit integer value.  Often used to represent Boolean values.
	class Int1	< ConstantInteger; end
	# 8 bit (1 byte)  integer value.
	class Int8	< ConstantInteger; end
	# 16 bit (2 byte) integer value.
	class Int16	< ConstantInteger; end
	# 32 bit (4 byte) integer value.
	class Int32	< ConstantInteger; end
	# 64 bit (8 byte) integer value.
	class Int64	< ConstantInteger; end

	# The native integer value class on the current (not the target) platform.
	NativeInt = RLTK::CG.const_get("Int#{FFI.type_size(:int) * 8}")

	# A constant Int 1 representing the Boolean value TRUE.
	TRUE		= Int1.new(-1)
	# A constant Int 1 representing the Boolean value FALSE.
	FALSE	= Int1.new( 0)

	# All real constants inherit from this class.
	#
	# @abstract
	class ConstantReal < ConstantNumber
		include Filigree::AbstractClass

		# Create a constant real number using a Ruby value or a string.
		#
		# @param [::Float, String]	num_or_string	Ruby value or string representation of a float.
		# @param [Integer, nil]		size			Optional length of string to use.
		def initialize(num_or_string, size = nil)
			@ptr =
			if num_or_string.is_a?(::Float)
				Bindings.const_real(self.type, num_or_string)

			elsif size
				Bindings.const_real_of_string_and_size(self.type, num_or_string, size)

			else
				Bindings.const_real_of_string(self.type, num_or_string)
			end
		end

		# Negate this value.
          #
          # @return [ConstantReal] Instance of the same class
		def -@
			self.class.new(Bindings.const_f_neg(@ptr))
		end

		# Add this value with another value.
          #
          # @param [ConstantReal] rhs
          #
          # @return [ConstantReal] Instance of the same class.
		def +(rhs)
			self.class.new(Bindings.const_f_add(@ptr, rhs))
		end

		# Subtract a value from this value.
          #
          # @param [ConstantReal] rhs
          #
          # @return [ConstantReal] Instance of the same class.
		def -(rhs)
			self.class.new(Bindings.const_f_sub(@ptr, rhs))
		end

		# Multiply this value with another value.
          #
          # @param [ConstantReal] rhs
          #
          # @return [ConstantReal] Instance of the same class.
		def *(rhs)
			self.class.new(Bindings.const_f_mul(@ptr, rhs))
		end

		# Divide this value by another value.
          #
          # @param [ConstantReal] rhs
          #
          # @return [ConstantReal] Instance of the same class.
		def /(rhs)
			self.class.new(Bindings.const_f_div(@ptr, rhs))
		end

		# Modulo this value by another value.
          #
          # @param [ConstantReal] rhs
          #
          # @return [ConstantReal] Instance of the same class.
		def %(rhs)
			self.class.new(Bindings.const_f_remm(@ptr, rhs))
		end

		# Compare this value to another value.
          #
          # @see Bindings._enum_real_predicate_
          #
          # @param [Symbol]		pred An real predicate.
          # @param [ConstantReal]	rhs  Value to compare to.
          #
          # @return [Int1] Value used to represent a Boolean value.
		def cmp(pred, rhs)
			Int1.new(Bindings.const_f_cmp(pred, @ptr, rhs))
		end

		# Cast this constant real to another number type.
		#
		# @param [NumberType]	type		Desired type to cast to.
		#
		# @return [ConstantNumber] Constant number of given type.
		def cast(type)
			type.value_class.new(Bindings.const_fp_cast(@ptr, check_cg_type(type, NumberType)))
		end

		# Convert this real number into an integer.
		#
		# @param [BasicIntType]	type		Type to convert to.
		# @param [Boolean]		signed	Should the result be a signed integer or not.
		#
		# @return [
		def to_i(type = NativeIntType, signed = true)
			type.value_class.new(Bindings.send(signed ? :const_fp_to_si : :const_fp_to_ui, @ptr, check_cg_type(type, BasicIntType)))
		end

		# Extend a constant real number to a larger size.
		#
		# @param [RealType] type Type to extend to.
		#
		# @return [ConstantReal] This value as a real of the given type.
		def extend(type)
			type.value_class.new(Bindings.const_fp_ext(@ptr, check_cg_type(type, RealType)))
		end

		# Truncate a constant real number to a smaller size.
		#
		# @param [RealType] type Type to truncate to.
		#
		# @return [ConstantReal] This value as a real of the given type.
		def truncate(type)
			type.value_class.new(Bindings.const_fp_trunc(@ptr, check_cg_type(type, RealType)))
		end
	end

	# A 16-bit floating point number value.
	class Half     < ConstantReal; end
	# A double precision floating point number value.
	class Double   < ConstantReal; end
	# A single precision floating point number value.
	class Float    < ConstantReal; end
	# A 128 bit (16 byte) floating point number value.
	class FP128    < ConstantReal; end
	# A 128 bit (16 byte) floating point number value for the PPC architecture.
	class PPCFP128 < ConstantReal; end
	# A 80 bit (10 byte) floating point number value for the x86 architecture.
	class X86FP80  < ConstantReal; end

	# This class represents global constants, variables, and functions.
	class GlobalValue < Constant
		# Global values can only be instantiated using a pointer, and as such
		# should not be created directly by library users.
		#
		# @param [FFI::Pointer] ptr
		def initialize(ptr)
			@ptr = check_type(ptr, FFI::Pointer, 'ptr')
		end

		# Get the byte alignment of this value.
		#
		# @return [Integer]
		def alignment
			Bindings.get_alignment(@ptr)
		end

		# Set the byte alignment of this value.
		#
		# @param [Integer] bytes
		#
		# @return [void]
		def alignment=(bytes)
			Bindings.set_alignment(@ptr, bytes)
		end

		# Check if this value is a declaration.
		#
		# @return [Boolean]
		def declaration?
			Bindings.is_declaration(@ptr).to_bool
		end

		# Sets the externally initialized property of a global value.
		#
		# @param [Boolean]  bool  If the value is externally initialized
		#
		# @return [void]
		def externally_initialized=(bool)
			Bindings.set_externally_initialized(@ptr, bool.to_i)
		end

		# Check if this global is initialized externally.
		#
		# @return [Boolean]
		def externally_initialized?
			Bindings.externally_initialized(@ptr).to_bool
		end

		# Check if this value is a global constant.
		#
		# @return [Boolean]
		def global_constant?
			Bindings.is_global_constant(@ptr).to_bool
		end

		# Set this value as a global constant or not.
		#
		# @param [Boolean] flag
		#
		# @return [void]
		def global_constant=(flag)
			Bindings.set_global_constant(@ptr, flag.to_i)
		end

		# Get this value's initializer.
		#
		# @return [Value]
		def initializer
			Value.new(Bindings.get_initializer(@ptr))
		end

		# Set this value's initializer.
		#
		# @param [Value] val
		#
		# @return [void]
		def initializer=(val)
			Bindings.set_initializer(@ptr, check_type(val, Value, 'val'))
		end

		# Get this value's linkage type.
		#
		# @see Bindings._enum_linkage_
		#
		# @return [Symbol]
		def linkage
			Bindings.get_linkage(@ptr)
		end

		# Set this value's linkage type.
		#
		# @see Bindings._enum_linkage_
		#
		# @param [Symbol] linkage
		#
		# @return [void]
		def linkage=(linkage)
			Bindings.set_linkage(@ptr, linkage)
		end

		# Get this value's section string.
		#
		# @return [String]
		def section
			Bindings.get_section(@ptr)
		end

		# Set this value's section string.
		#
		# @param [String] section
		#
		# @return [void]
		def section=(section)
			Bindings.set_section(@ptr, section)
		end

		# Returns the thread local model used by a global value.
		#
		# @return [Symbol from _enum_thread_local_mode_]
		def thread_local_mode
			Bindings.get_thread_local_mode(@ptr)
		end


		# Set the global value's thread local mode.
		#
		# @param [Symbol from _enum_thread_local_mode_] mode
		#
		# @return [void]
		def thread_local_mode=(mode)
			Bindings.set_thread_local_mode(@ptr, mode)
		end

		# Get this value's visibility.
		#
		# @see Bindings._enum_visibility_
		#
		# @return [String]
		def visibility
			Bindings.get_visibility(@ptr)
		end

		# Set this value's visibility.
		#
		# @see Bindings._enum_visibility_
		#
		# @param [Symbol] vis
		#
		# @return [void]
		def visibility=(vis)
			Bindings.set_visibility(@ptr, vis)
		end
	end

	# This class represents global aliases.
	class GlobalAlias < GlobalValue
	end

	# This class represents global variables.
	class GlobalVariable < GlobalValue
		# Check to see if this global variable is thread local.
		#
		# @return [Boolean]
		def thread_local?
			Bindings.is_thread_local(@ptr).to_bool
		end

		# Set this global variable as thread local or not.
		#
		# @param [Boolean] local
		#
		# @return [void]
		def thread_local=(local)
			Bindings.set_thread_local(@ptr, local.to_i)
		end
	end
end

####################
# Helper Functions #
####################

# A helper function for creating constant array, vector, and struct types.
# This method should never be used by library users.
#
# @param [Array<RLTK::CG::Value>, Integer]	size_or_values	Number of values or array of values.
# @param [Proc]						block		Block evaluated if size is specified.
#
# @return [FFI::MemoryPointer] An array of pointers to LLVM Values.
def make_ptr_to_elements(size_or_values, &block)
	values =
	case size_or_values
	when Integer
		raise ArgumentError, 'Block not given.' if not block_given?

		::Array.new(size_or_values, &block)
	else
		size_or_values
	end

	FFI::MemoryPointer.new(:pointer, values.size).write_array_of_pointer(values)
end
