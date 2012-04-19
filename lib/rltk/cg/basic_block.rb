# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/07
# Description:	This file defines the BasicBlock class.

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
	class BasicBlock < Value
		def initialize(overloaded, name = '', context = nil)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
				
			when Function
				if context
					Bindings.append_basic_block_in_context(context, overloaded, name)
				else
					Bindings.append_basic_block(overloaded, name)
				end
				
			when BasicBlock
				if context
					Bindings.insert_basic_block_in_context(context, overloaded, name)
				else
					Bindings.insert_basic_block(overloaded, name)
				end
			end
		end
		
		def build(builder = nil, &block)
			if builder
				builder.position_at_end(self).build(&block)
				
			else
				builder	= Builder.new(self)
				last_inst	= builder.build(&block)
				
				builder.dispose
				
				last_inst
			end
		end
		
		def insert_before(name = '', context = nil)
			BasicBlock.new(self, name, context)
		end
		
		def instructions
			@instructions ||= InstructionCollection.new(self)
		end
		
		def next
			if (bb = Bindings.get_next_basic_block(@ptr)).null? then nil else BasicBlock.new(bb) end 
			BasicBlock.new(bb) unless bb.null?
		end
		
		def parent
			if (fp = Bindings.get_basic_block_parent(@ptr)).null? then nil else Function.new(fp) end
		end
		
		def previous
			if (bb = Bindings.get_previous_basic_block(@ptr)).null? then nil else BasicBlock.new(bb) end
		end
		
		class InstructionCollection
			include Enumerable
			
			def initialize(bb)
				@bb = bb
			end
			
			def each
				return to_enum(:each) unless block_given?
				
				inst, last = self.first, self.last
				
				while inst
					yield inst
					inst = inst.next
				end
				
				self
			end
			
			def first
				if (ptr = Bindings.get_first_instruction(@bb)).null? then nil else Instruction.from_ptr(ptr) end
			end
			
			def last
				if (ptr = Bindings.get_last_instruction(@bb)).null? then nil else Instruction.from_ptr(ptr) end
			end
		end
	end
end
