# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/18
# Description:	This file defines the GenericValue class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/type'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# GenericValue objects are used to pass parameters into
	# {ExecutionEngine ExecutionEngines} as well as retreive an evaluated
	# function's result.  They may contain values of several different types:
	#
	#  * Integer
	#  * Float
	#  * Boolean
	class GenericValue
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_generic_value(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# @return [Type] LLVM type of this GenericValue.
		attr_reader :type

		# Creates a new GenericValue from a given Ruby value.
		#
		# @param [FFI::Pointer, Integer, ::Float, Boolean]	ruby_val
		# @param [Type]								type		Type of Integer or Float to create.
		# @param [Boolean]								signed	Signed or unsigned Integer.
		def initialize(ruby_val, type = nil, signed = true)
			@ptr, @type =
			case ruby_val
			when FFI::Pointer
				[ruby_val, nil]

			when ::Integer
				type = if type then check_cg_type(type, IntType) else NativeIntType.instance end

				[Bindings.create_generic_value_of_int(type, ruby_val, signed.to_i), type]

			when ::Float
				type = if type then check_cg_type(type, RealType) else FloatType.instance end

				[Bindings.create_generic_value_of_float(type, ruby_val), type]

			when TrueClass
				[Bindings.create_generic_value_of_int(Int1Type, 1, 0), Int1Type]

			when FalseClass
				[Bindings.create_generic_value_of_int(Int1Type, 0, 0), Int1Type]
			end

			# Define a finalizer to free the memory used by LLVM for this
			# generic value.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
		end

		# @param [Boolean] signed Treat the GenericValue as a signed integer.
		#
		# @return [Integer]
		def to_i(signed = true)
			val = Bindings.generic_value_to_int(@ptr, signed.to_i)

			if signed and val >= 2**63 then val - 2**64 else val end
		end

		# @param [FloatType] type Type of the real value stored in this GenericValue.
		#
		# @return [Float]
		def to_f(type = RLTK::CG::FloatType)
			Bindings.generic_value_to_float(@type || check_cg_type(type, RLTK::CG::NumberType), @ptr)
		end

		# @return [Boolean]
		def to_bool
			self.to_i(false).to_bool
		end

		# @return [FFI::Pointer] GenericValue as a pointer.
		def to_ptr_value
			Bindings.generic_value_to_pointer(@ptr)
		end
	end
end
