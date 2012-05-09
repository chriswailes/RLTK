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
	class GenericValue
		include BindingClass
		
		attr_reader :type
		
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
		end
		
		def dispose
			if @ptr
				Bindings.dispose_generic_value(@ptr)
				@ptr = nil
			end
		end
	
		def to_i(signed = true)
			val = Bindings.generic_value_to_int(@ptr, signed.to_i)
			
			if signed and val >= 2**63 then val - 2**64 else val end
		end
	
		def to_f(type = RLTK::CG::FloatType)
			Bindings.generic_value_to_float(@type || check_cg_type(type, RLTK::CG::NumberType), @ptr)
		end
	
		def to_b
			self.to_i(false).to_bool
		end
	
		def to_value_ptr
			Bindings.generic_value_to_pointer(@ptr)
		end
	end
end
