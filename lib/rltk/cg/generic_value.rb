# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/18
# Description:	This file defines the GenericValue class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class GenericValue < BindingClass
		attr_reader :type
		
		def initialize(ruby_val, type = nil, signed = true)
			@ptr, @type =
			case ruby_val
			when FFI::Pointer
				Bindings.create_generic_value_of_pointer(ruby_val), nil
				
			when Fixnum
				type ||= NativeIntType
				
				Bindings.create_generic_value_of_int(type, ruby_val, signed.to_i), type
				
			when Float
				type ||= FloatType
				
				Bindings.create_generic_value_of_float(type, ruby_val), type
				
			when TrueClass
				Bindings.create_generic_value_of_int(Int1Type, 1, 0), Int1Type
				
			when FalseClass
				Bindings.create_generic_value_of_int(Int1Type, 0, 0), Int1Type
			end
		end
	end
	
	def dispose
		if @ptr
			Bindings.dispose_generic_value(@ptr)
			@ptr = nil
		end
	end
	
	def to_i(signed = true)
		val  = Bindings.generic_value_to_int(@ptr, signed.to_i)
		val -= 2**64 if signed and v >= 2**63
		val
	end
	
	def to_f(type)
		Bindings.generic_value_to_float(@type, @ptr)
	end
	
	def to_b
		self.to_i(false).to_bool
	end
	
	def to_value_ptr
		Bindings.generic_value_to_pointer(@ptr)
	end
end
