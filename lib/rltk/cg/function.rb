# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/06
# Description:	This file defines the Function class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/basic_block'
require 'rltk/cg/value'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# An LLVM IR function.
	class Function < GlobalValue
		# @return [FunctionType] FunctionType object describing this function's type.
		attr_reader :type

		# Define a new function in a given module.  You can also use the
		# {Module::FunctionCollection#add} method to add functions to
		# modules.
		#
		# @param [FFI::Pointer, Module]				overloaded	Pointer to a function objet or a module.
		# @param [String]							name			Name of the function in LLVM IR.
		# @param [FunctionType, Array(Type, Array<Type>)]	type_info		FunctionType or Values that will be passed to {FunctionType#initialize}.
		# @param [Proc]							block		Block to be executed inside the context of the function.
		#
		# @raise [RuntimeError] An error is raised if the overloaded parameter is of an incorrect type.
		def initialize(overloaded, name = '', *type_info, &block)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded

			when RLTK::CG::Module
				@type = if type_info.first.is_a?(FunctionType) then type_info.first else FunctionType.new(*type_info) end

				Bindings.add_function(overloaded, name.to_s, @type)

			else
				raise 'The first argument to Function.new must be either a pointer or an instance of RLTK::CG::Module.'
			end

			self.instance_exec(self, &block) if block
		end

		# @return [FunctionAttrCollection] Proxy object for inspecting function attributes.
		def attributes
			@attributes ||= FunctionAttrCollection.new(self)
		end
		alias :attrs :attributes

		# @return [BasicBlockCollection] Proxy object for inspecting a function's basic blocks.
		def basic_blocks
			@basic_blocks ||= BasicBlockCollection.new(self)
		end
		alias :blocks :basic_blocks

		# Get a function's calling convention.
		#
		# @see Bindings._enum_call_conv_
		#
		# @return [Symbol]
		def calling_convention
			Bindings.enum_type(:call_conv)[Bindings.get_function_call_conv(@ptr)]
		end

		# Set a function's calling convention.
		#
		# @see Bindings._enum_call_conv_
		#
		# @param [Symbol] conv Calling convention to set.
		def calling_convention=(conv)
			Bindings.set_function_call_conv(@ptr, Bindings.enum_type(:call_conv)[conv])

			conv
		end

		# @return [ParameterCollection] Proxy object for inspecting a function's parameters.
		def parameters
			@parameters ||= ParameterCollection.new(self)
		end
		alias :params :parameters

		# Verify that the function is valid LLVM IR.
		#
		# @return [nil, String] Human-readable description of any invalid constructs if invalid.
		def verify
			do_verification(:return_status)
		end

		# Verify that the function is valid LLVM IR and abort the process if it isn't.
		#
		# @return [nil]
		def verify!
			do_verification(:abort_process)
		end

		# Helper function for {#verify} and {#verify!}
		def do_verification(action)
			Bindings.verify_function(@ptr, action).to_bool
		end
		private :do_verification

		# This class is used to access a function's {BasicBlock BasicBlocks}
		class BasicBlockCollection
			include Enumerable

			# @param [Function] fun Function for which this is a proxy.
			def initialize(fun)
				@fun = fun
			end

			# Add a {BasicBlock} to the end of this function.
			#
			# @note The first argument to any proc passed to this function
			#	will be the function the block is being appended to.
			#
			# @param [String]		name			Name of the block in LLVM IR.
			# @param [Builder, nil]	builder		Builder to be used in evaluating *block*.
			# @param [Context, nil]	context		Context in which to create the block.
			# @param [Array<Object>]	block_args	Arguments to be passed to *block*.  The function the block is appended to is automatically added to the front of this list.
			# @param [Proc]		block		Block to be evaluated using *builder* after positioning it at the end of the new block.
			#
			# @return [BasicBlock] New BasicBlock.
			def append(name = '', builder = nil, context = nil, *block_args, &block)
				BasicBlock.new(@fun, name, builder, context, *block_args, &block)
			end

			# An iterator for each block inside this collection.
			#
			# @yieldparam block [BasicBlock]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum :each unless block_given?

				ptr = Bindings.get_first_basic_block(@fun)

				self.size.times do |i|
					yield BasicBlock.new(ptr)
					ptr = Bindings.get_next_basic_block(ptr)
				end
			end

			# @return [BasicBlock, nil] The function's entry block if it has been added.
			def entry
				if (ptr = Bindings.get_entry_basic_block(@fun)) then BasicBlock.new(ptr) else nil end
			end

			# @return [BasicBlock, nil] The function's first block if one has been added.
			def first
				if (ptr = Bindings.get_first_basic_block(@fun)) then BasicBlock.new(ptr) else nil end
			end

			# @return [BasicBlock, nil] The function's last block if one has been added.
			def last
				if (ptr = Bindings.get_last_basic_block(@fun)) then BasicBlock.new(ptr) else nil end
			end

			# @return [Integer] Number of basic blocks that comprise this function.
			def size
				Bindings.count_basic_blocks(@fun)
			end
		end

		# This class is used to access a function's attributes.
		class FunctionAttrCollection < AttrCollection
			@@add_method = :add_function_attr
			@@del_method = :remove_function_attr

			# Set a target-dependent function attribute.
			#
			# @param [String]  attribute  Attribute name
			# @param [String]  value      Attribute value
			#
			# @return [void]
			def add_td_attr(attribute, value)
				Bindings.add_target_dependent_function_attr(@value, attribute, value)
			end
		end


		# This class is used to access a function's parameters.
		class ParameterCollection
			include Enumerable

			# @param [Function] fun Function for which this is a proxy.
			def initialize(fun)
				@fun = fun
			end

			# Access the parameter at the given index.
			#
			# @param [Integer] index Index of the desired parameter.  May be negative.
			#
			# @return [Value] Value object representing the parameter.
			def [](index)
				index += self.size if index < 0

				if 0 <= index and index < self.size
					Value.new(Bindings.get_param(@fun, index))
				end
			end

			# An iterator for each parameter inside this collection.
			#
			# @yieldparam val [Value]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum :each unless block_given?

				self.size.times { |index| yield self[index] }

				self
			end

			# @return [Integer] Number of function parameters.
			def size
				Bindings.count_params(@fun)
			end

			# @return [Array<Value>] Array of Value objects representing the function parameters.
			def to_a
				self.size.times.to_a.inject([]) { |params, index| params << self[index] }
			end
		end
	end
end
