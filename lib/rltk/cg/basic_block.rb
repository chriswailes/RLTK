# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/07
# Description:	This file defines the BasicBlock class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/context'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# A BasicBlock is what instructions are inserted into and what functions
	# are made of.  BasicBlock objects may be created either using
	# BasicBlock.new or using the {Function::BasicBlockCollection#append}
	# method.
	class BasicBlock < Value

		# Create a new BasicBlock object.  The way the block is created is
		# determined by the *overloaded* parameter.  If it is a Function
		# object then the new block is appended to the end of the function.
		# If *overloaded* is another BasicBlock object the new block will
		# be inserted before that block.
		#
		# A block may be given to this function to be invoked by {#build}.
		#
		# @param [FFI::Pointer, Function, BasicBlock] overloaded Overloaded paramater that determines creation behaviour.
		#
		# @param [String]		name			Name of this BasicBlock.
		# @param [Builder, nil]	builder		Builder to be used by {#build}.
		# @param [Context, nil]	context		Context in which to create the block.
		# @param [Array<Object>]	block_args	Arguments to be passed when block is invoked.
		# @param [Proc]		block		Block to be invoked by {#build}.
		def initialize(overloaded, name = '', builder = nil, context = nil, *block_args, &block)
			check_type(context, Context, 'context') if context

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

			self.build(builder, *block_args, &block) if block
		end

		# Used to add instructions to a BasicBlock.  The block given to this
		# method is executed inside the context of a {Builder} object, either
		# the one passed in the *builder* parameter or one created for this
		# call.  Arguments may be passed into this block via the *block_args*
		# parameter.
		#
		# @example
		#     fun = Function.new(...)
		#     block.build do
		#          ret add(fun.params[0], fun.params[1])
		#     end
		#
		# @param [Builder, nil]	builder		Builder in which to execute this block.
		# @param [Array<Object>]	block_args	Arguments to pass into block.
		# @param [Proc]		block		Block to execute inside builder.
		#
		# @return [Object] Value the block evaluates to.  Usually an {Instruction}
		def build(builder = nil, *block_args, &block)
			if builder then builder else Builder.new end.build(self, *block_args, &block)
		end

		# Creates a new BasicBlock inserted immediately before this block.
		#
		# @param [String]	name		Name of this BasicBlock.
		# @param [Context]	context	Context in which to create this BasicBlock.
		#
		# @return [BasicBlock]
		def insert_before(name = '', context = nil)
			BasicBlock.new(self, name, context)
		end

		# @return [InstructionCollect] Collection of all instructions inside this BasicBlock.
		def instructions
			@instructions ||= InstructionCollection.new(self)
		end

		# @return [BasicBlock, nil] BasicBlock that occures immediately after this block or nil.
		def next
			if (ptr = Bindings.get_next_basic_block(@ptr)).null? then nil else BasicBlock.new(ptr) end
		end

		# @return [Function] Function object that this BasicBlock belongs to.
		def parent
			if (ptr = Bindings.get_basic_block_parent(@ptr)).null? then nil else Function.new(ptr) end
		end

		# @return [BasicBlock, nil] BasicBlock that occures immediately before this block or nil.
		def previous
			if (ptr = Bindings.get_previous_basic_block(@ptr)).null? then nil else BasicBlock.new(ptr) end
		end

		# This class is used to access all of the {Instruction Instructions} that have been added to a {BasicBlock}.
		class InstructionCollection
			include Enumerable

			# @param [BasicBlock] bb BasicBlock this collection belongs to.
			def initialize(bb)
				@bb = bb
			end

			# Iterate over each {Instruction} in this collection.
			#
			# @yieldparam inst [Instruction]
			#
			# @return [Enumerator] An Enumerator is returned if no block is given.
			def each
				return to_enum(:each) unless block_given?

				inst = self.first

				while inst
					yield inst
					inst = inst.next
				end

				self
			end

			# @return [Instruction] First instruction in this collection.
			def first
				if (ptr = Bindings.get_first_instruction(@bb)).null? then nil else Instruction.from_ptr(ptr) end
			end

			# @return [Instruction] Last instruction in this collection.
			def last
				if (ptr = Bindings.get_last_instruction(@bb)).null? then nil else Instruction.from_ptr(ptr) end
			end
		end
	end
end
