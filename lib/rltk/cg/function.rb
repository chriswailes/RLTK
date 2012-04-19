# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/06
# Description:	This file defines the Function class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Function < GlobalValue
		attr_reader :type
		
		# FIXME Needs to handle overloading
		def initialize(mod, *type_info)
			# See Module::FunctionCollection.add
		end
		
		def attributes
			@attributes ||= FunctionAttrCollection.new(@ptr)
		end
		alias :attrs :attributes
		
		def basic_blocks
			@basic_blocks ||= BasicBlockCollection.new(@ptr)
		end
		alias :blocks :basic_blocks
		
		def calling_convention
			Bindings.get_function_call_conv(@ptr)
		end
		
		def calling_convention=(conv)
			Bindings.set_function_call_conv(@ptr, conv)
			
			conv
		end
		
		def parameters
			@parameters ||= ParametersCollection
		end
		alias :params :parameters
		
		class BasicBlockCollection
			include Enumerable
			
			def initialize(fun)
				@fun = fun
			end
			
			def append(name = '')
				BasicBlock.new(@fun, name)
			end
			
			def each
				return to_enum :each unless block_given?
				
				ptr = Bindings.get_first_basic_block(@fun)
				
				self.size.times do |i|
					yield BasicBlock.new(ptr)
					ptr = Bindings.get_next_basic_block(ptr)
				end
			end
			
			def entry
				BasicBlock.new(Bindings.get_entry_basic_block(@fun))
			end
			
			def first
				if ptr = Bindings.get_first_basic_block(@fun) then BasicBlock.new(prt) else nil end
			end
			
			def last
				if ptr = Bindings.get_last_basic_block(@fun) then BasicBlock.new(prt) else nil end
			end
			
			def size
				Bindings.count_basic_blocks(@fun)
			end
		end
		
		class FunctionAttrCollection < AttrCollection
			@@add_method = :add_function_attr
			@@del_method = :remove_function_attr
		end
		
		class ParametersCollection
			include Enumerable
			
			def initialize(fun)
				@fun = fun
			end
			
			def [](index)
				limit = if index < 0 then self.size + index else self.size end
				
				if 0 <= index and index < limit
					Value.new(Bindings.get_param(@fun, index))
				end
			end
			
			def each
				return to_enum :each unless block_given?
				
				self.size.times { |i| yield self[i] }
				
				self
			end
			
			def size
				Bindings.count_params(@fun)
			end
		end
	end
end
