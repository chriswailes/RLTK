# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines LLVM Value classes.

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
	class Value < BindingClass
		attr_reader :attributes
		
		def initialize
			raise 'The Value class can not be instantiated directly.' if self.class == Value
			
			@attributes = AttrCollection.new(self)
		end
		
		def add_attribute(attribute)
			Bindings.add_attribute(@ptr, attribute)
		end
		
		def constant?
			Bindings.is_constant(@ptr).to_bool
		end
		
		def dump
			Bindings.dump_value(@ptr)
		end
		
		def hash
			@ptr.address.hash
		end
		
		def name
			Bindings.get_value_name(@ptr)
		end
		
		def name=(str)
			raise 'The str parameter must be a String.' if not str.instance_of?(String)
			
			Bindings.set_value_name(@ptr, str)
			
			return str
		end
		
		def null?
			Bindings.is_null(@ptr).to_bool
		end
		
		# FIXME Is this even needed?
		def type
		end
		
		def undefined?
			Bindings.is_undef(@ptr).to_bool
		end
		
		class AttrCollection
			@@add_method = :add_attribute
			@@del_method = :remove_attribute
			
			def initialize(value)
				@attributes	= Array.new
				@value		= value
			end
			
			def add_attribute(attribute)
				if not @attributes.include?(attribute)
					@attributes << attribute
					Bindings.send(@@add_method, @value.to_ptr, attribute)
				end
			end
			alias :'<<' :add_attribute
			
			def include?(attribute)
				@attributes.include?(attribute)
			end
			
			def remove_attribute(attribute)
				if @attributes.include?(attribute)
					@attributes.delete(attribute)
					Bindings.send(@@del_method, @value.to_ptr, attribute)
				end
			end
			alias :'>>' :remove_attribute
			
			def to_s
				@attributes.to_s
			end
		end
	end
	
	class Argument < Value
	end
	
	class User < Value
	end
	
	class Constant < User
		def initialize(kind, type)
			raise 'The type parameter must be an instance of the RLTK::CG::Type class.' if not type.is_a?(Type)
			
			@ptr =
			case kind
			when :null	then Bindings.const_null(type)
			when :null_ptr	then Bindings.const_pointer_null(type)
			when :undef	then Bindings.get_undef(type)
			else raise 'Constants must be of kind :null, :null_ptr, or :undef.'
			end
		end
		
		def bitcast_to(type)
		end
		
		def get_element_ptr(*indices)
		end
	end
	
	class ConstantArray < Constant
	end
	
	class ConstantExpr < Constant
	end
	
	class ConstantInt < Constant
	end
	
	class ConstantReal < Constant
	end
	
	class Float < ConstantReal
	end
	
	class Double < ConstantReal
	end
	
	class ConstantStruct < Constant
	end
	
	class ConstantVector < Constnat
	end
	
	class GlobalValue < Constant
		def alignment
			Bindings.get_alignment(@ptr)
		end
		
		def alignment=(bytes)
			Bindings.set_alignment(@ptr, bytes)
		end
		
		def declaration?
			Bindings.is_declaration(@ptr)
		end
		
		def global_constant?
			Bindings.is_global_constant(@ptr)
		end
		
		def global_constant=(flag)
			Bindings.set_global_constant(@ptr, flag)
		end
		
		def initializer=(val)
			raise 'The val parameter must be of type RLTK::CG::Value.' if not val.is_a?(Value)
			
			Bidnings.set_initializer(@ptr, val)
		end
		
		def linkage
			Bindings.get_linkage(@ptr)
		end
		
		def linkage=(linkage)
			Bindings.set_linkage(@ptr, linkage)
		end
		
		def section
			Bindings.get_section(@ptr)
		end
		
		def section=(section)
			Bindings.set_section(@ptr, section)
		end
		
		def visibility
			Bindings.get_visibility(@ptr)
		end
		
		def visibility=(vis)
			Bindings.set_visibility(@ptr, vis)
		end
	end
	
	class GlobalAlias < GlobalValue
	end
	
	class GlobalVariable < GlobalValue
		def thread_local?
			Bindings.is_thread_local(@ptr).to_bool
		end
		
		def thread_local=(local)
			Bindings.set_thread_local(@ptr, local.to_i)
		end
	end
end
