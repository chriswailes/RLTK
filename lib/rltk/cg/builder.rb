# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Builder class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/instruction'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# This class is responsible for adding {Instruction Instructions} to {BasicBlock BasicBlocks}.
	class Builder
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_builder(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# @return [Builder] A global Builder object.
		def self.global
			@@global_builder ||= Builder.new
		end

		# Creates a new Builder object, optionally positioning it at the end
		# of *block*.  If a block is given it will be executed as if it was
		# passed to the #build method.
		#
		# @param [BasicBlock, nil]	bb			BasicBlock used to position the Builder.
		# @param [Array<Object>]		block_args	Arguments to be passed to *block*.
		# @param [Proc, nil]		block		Block to execute in the context of this Builder.
		def initialize(bb = nil, *block_args, &block)
			@ptr = Bindings.create_builder

			# Define a finalizer to free the memory used by LLVM for this
			# builder.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)

			if block then self.build(bb, *block_args, &block) elsif bb then position_at_end(bb) end
		end

		# Executes a given block inside the context of this builder.  If the
		# *bb* parameter isn't nill, the Builder will be positioned at the
		# end of the specified BasicBlock.
		#
		# @param [BasicBlock]	bb			Optional BasicBlock used to position the Builder.
		# @param [Array<Object>]	block_args	Arguments to be passed to *block*.
		# @param [Proc]		block		Block to execute in the context of this Builder.
		#
		# @return [Object] The result of evaluating *block* in the context of this Builder.
		def build(bb = nil, *block_args, &block)
			self.position_at_end(bb) if bb
			self.instance_exec(*block_args, &block)
		end

		# Build an instruction.
		#
		# @param [Symbol]		inst Name of instruction building method.
		# @param [Array<Object>] args Arguments to be passed to building method.
		#
		# @return [Instruction] Build instruction.
		def build_inst(inst, *args)
			self.send(inst, *args)
		end
		alias :'<<' :build_inst

		# Position the Builder after the given instruction.
		#
		# @param [BasicBlock]	bb
		# @param [Instruction]	instruction
		#
		# @return [Builder] self
		def position(bb, instruction)
			Bindings.position_builder(@ptr, bb, instruction) if check_type(bb, BasicBlock, 'bb')
			self
		end

		# Position the Builder at the end of the given BasicBlock.
		#
		# @param [BasicBlock] bb
		#
		# @return [Bulder] self
		def position_at_end(bb)
			Bindings.position_builder_at_end(@ptr, bb) if check_type(bb, BasicBlock, 'bb')
			self
		end
		alias :pae :position_at_end
		alias :target :position_at_end

		# Position the Builder before the given Instruction.
		#
		# @param [Instruction] instruction
		#
		# @return [Builder] self
		def position_before(instruction)
			Bindings.position_builder_before(@ptr, instruction)
			self
		end

		################################
		# Instruction Building Methods #
		################################

		#################
		# Miscellaneous #
		#################

		# @return [BasicBlock] BasicBlock the Builder is currently positioned on.
		def current_block
			BasicBlock.new(Bindings.get_insert_block(@ptr))
		end
		alias :insertion_block :current_block

		# Generates an instruction with no defined semantics. Can be used to
		# provide hints to the optimizer.
		#
		# @return [UnreachableInst]
		def unreachable
			UnreachableInst.new(Bindings.build_unreachable(@ptr))
		end

		###########
		# Returns #
		###########

		# @param [Value] val The Value to return.
		#
		# @return [ReturnInst]
		def ret(val)
			ReturnInst.new(Bindings.build_ret(@ptr, val))
		end

		# @return [RetVoidInst]
		def ret_void
			ReturnVoidInst.new(Bindings.build_ret_void(@ptr))
		end

		# @return [RetAggregateInst]
		def ret_aggregate(*vals)
			vals = vals.first if vals.length == 1 and vals.first.instance_of?(::Array)

			vals_ptr = FFI::MemoryPointer.new(:pointer, vals.length)
			vals_ptr.write_array_of_pointer(vals)

			ReturnAggregateInst.new(Bindings.build_aggregate_ret(@ptr, vals_ptr, vals.length))
		end

		################
		# Control Flow #
		################

		# Unconditional branching.
		#
		# @param [BasicBlock] block Where to jump.
		#
		# @return [BranchInst]
		def branch(block)
			BranchInst.new(Bindings.build_br(@ptr, block))
		end
		alias :br :branch

		# Build an instruction that performs a function call.
		#
		# @param [Function]		fun	Function to call.
		# @param [Array<Value>]	args	Arguments to pass to function.
		#
		# @return [CallInst]
		def call(fun, *args)
			name = if args.last.is_a?(String) then args.pop else '' end

			args_ptr = FFI::MemoryPointer.new(:pointer, args.length)
			args_ptr.write_array_of_pointer(args)

			CallInst.new(Bindings.build_call(@ptr, fun, args_ptr, args.length, name))
		end

		# Conditional branching.
		#
		# @param [Value]		val		Condition value.
		# @param [BasicBlock]	iffalse	Where to jump if condition is true.
		# @param [BasicBlock]	iftrue	Where to jump if condition is false.
		#
		# @return [CondBranchInst]
		def cond_branch(val, iftrue, iffalse)
			CondBranchInst.new(Bindings.build_cond_br(@ptr, val, iftrue, iffalse))
		end
		alias :cond :cond_branch

		# Extract an element from a vector.
		#
		# @param [Value]	vector	Vector from which to extract a value.
		# @param [Value]	index	Index of the element to extract, an unsigned integer.
		# @param [String]	name		Value of the result in LLVM IR.
		#
		# @return [ExtractElementInst] The extracted element.
		def extract_element(vector, index, name = '')
			ExtractElementInst.new(Bindings.build_extract_element(@ptr, vector, index, name))
		end

		# Extract the value of a member field from an aggregate value.
		#
		# @param [Value]	aggregate	An aggregate value.
		# @param [Value]	index	Index of the member to extract.
		# @param [String]	name		Name of the result in LLVM IR.
		#
		# @return [ExtractValueInst] The extracted value.
		def extract_value(aggregate, index, name = '')
			ExtractValueInst.new(Bindings.build_extract_value(@ptr, aggregate, index, name))
		end

		# Insert an element into a vector.
		#
		# @param [Value]	vector	Vector into which to insert the element.
		# @param [Value]	element	Element to be inserted into the vector.
		# @param [Value]	index	Index at which to insert the element.
		# @param [String]	name		Name of the result in LLVM IR.
		#
		# @return [InsertElementInst] A vector the same type as *vector*.
		def insert_element(vector, element, index, name = '')
			InsertElementInst.new(Bindings.build_insert_element(@ptr, vector, element, index, name))
		end

		# Insert a value into an aggregate value's member field.
		#
		# @param [Value]	aggregate	An aggregate value.
		# @param [Value]	val		Value to insert into *aggregate*.
		# @param [Value]	index	Index at which to insert the value.
		# @param [String]	name		Name of the result in LLVM IR.
		#
		# @return [InsertValueInst] An aggregate value of the same type as *aggregate*.
		def insert_value(aggregate, val, index, name = '')
			InsertValueInst.new(Bindings.build_insert_value(@ptr, aggregate, val, index, name))
		end

		# Invoke a function which may potentially unwind.
		#
		# @param [Function]		fun 		Function to invoke.
		# @param [Array<Value>]	args		Arguments passed to fun.
		# @param [BasicBlock]	normal	Where to jump if fun does not unwind.
		# @param [BasicBlock]	exception	Where to jump if fun unwinds.
		# @param [String]		name		Name of the result in LLVM IR.
		#
		# @return [InvokeInst] The value returned by *fun*, unless an unwind instruction occurs.
		def invoke(fun, args, normal, exception, name = '')
			InvokeInst.new(Bindings.build_invoke(@ptr, fun, args, args.length, normal, exception, name))
		end

		# Build a Phi node of the given type with the given incoming
		# branches.
		#
		# @param [Type]					type		Specifies the result type.
		# @param [Hash{BasicBlock => Value}]	incoming	A hash mapping basic blocks to a
		#   corresponding value. If the phi node is jumped to from a given basic block,
		#   the phi instruction takes on its corresponding value.
		# @param [String]					name		Name of the result in LLVM IR.
		#
		# @return [PhiInst] The phi node.
		def phi(type, incoming, name = '')
			PhiInst.new(Bindings.build_phi(@ptr, check_cg_type(type), name)).tap do |phi|
				phi.incoming.add(incoming)
			end
		end

		# Return a value based on a condition. This differs from *cond* in
		# that its operands are values rather than basic blocks. As a
		# consequence, both arguments must be evaluated.
		#
		# @param [Value]	if_val		An Int1 or a vector of Int1.
		# @param [Value]	then_val	Value or vector of the same arity as *if_val*.
		# @param [Value]	else_val	Value or vector of values of the same arity
		#   as *if_val*, and of the same type as *then_val*.
		# @param [String]	name		Name of the result in LLVM IR.
		#
		# @return [SelectInst] An instruction representing either *then_val* or *else_val*.
		def select(if_val, then_val, else_val, name = '')
			SelectInst.new(Bindings.build_select(@ptr, if_val, then_val, else_val, name))
		end

		# Shuffle two vectors according to a given mask.
		#
		# @param [Value]	vec1 Vector
		# @param [Value]	vec2 Vector of the same type and arity as *vec1*.
		# @param [Value]	mask Vector of Int1 of the same arity as *vec1* and *vec2*.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [ShuffleVectorInst] The shuffled vector.
		def shuffle_vector(vec1, vec2, mask, name = '')
			ShuffleVectorInst.new(Bindings.build_shuffle_vector(@ptr, vec1, vec2, mask, name))
		end

		# Select a value based on an incoming value.
		# @param [Value]					val		Value to switch on.
		# @param [BasicBlock]				default	Default case.
		# @param [Hash{Value => BasicBlock}]	cases	Hash mapping values
		#   to basic blocks. When a value is matched, control will jump to
		#   the corresponding basic block.
		#
		# @return [SwitchInst]
		def switch(val, default, cases)
			SwitchInst.new(Bindings.build_switch(@ptr, val, default, cases.size)).tap do |inst|
				cases.each { |val, block| inst.add_case(val, block) }
			end
		end

		########
		# Math #
		########

		# Addition

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [AddInst] The integer sum of the two operands.
		def add(lhs, rhs, name = '')
			AddInst.new(Bindings.build_add(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Floating point or vector of floating points.
		# @param [Value]	rhs	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FAddInst] The floating point sum of the two operands.
		def fadd(lhs, rhs, name = '')
			FAddInst.new(Bindings.build_f_add(@ptr, lhs, rhs, name))
		end

		# No signed wrap addition.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NSWAddInst] The integer sum of the two operands.
		def nsw_add(lhs, rhs, name = '')
			NSWAddInst.new(Bindings.build_nsw_add(@ptr, lhs, rhs, name))
		end

		# No unsigned wrap addition.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NSWAddInst] The integer sum of the two operands.
		def nuw_add(lhs, rhs, name = '')
			NUWAddInst.new(Bindings.build_nuw_add(@ptr, lhs, rhs, name))
		end

		# Subtraction

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SubInst] The integer difference of the two operands.
		def sub(lhs, rhs, name = '')
			SubInst.new(Bindings.build_sub(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Floating point or vector of floating points.
		# @param [Value]	rhs	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FSubInst] The floating point difference of the two operands.
		def fsub(lhs, rhs, name = '')
			FSubInst.new(Bindings.build_f_sub(@ptr, lhs, rhs, name))
		end

		# No signed wrap subtraction.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SubInst] The integer difference of the two operands.
		def nsw_sub(lhs, rhs, name = '')
			NSWSubInst.new(Bindings.build_nsw_sub(@ptr, lhs, rhs, name))
		end

		# No unsigned wrap subtraction.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SubInst] The integer difference of the two operands.
		def nuw_sub(lhs, rhs, name = '')
			NUWSubInst.new(Bindings.build_nuw_sub(@ptr, lhs, rhs, name))
		end

		# Multiplication

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [MulInst] The integer product of the two operands.
		def mul(lhs, rhs, name = '')
			MulInst.new(Bindings.build_mul(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Floating point or vector of floating points.
		# @param [Value]	rhs	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FMulInst] The floating point product of the two operands.
		def fmul(lhs, rhs, name = '')
			FMulInst.new(Bindings.build_f_mul(@ptr, lhs, rhs, name))
		end

		# No signed wrap multiplication.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [MulInst] The integer product of the two operands.
		def nsw_mul(lhs, rhs, name = '')
			NSWMulInst.new(Bindings.build_nsw_mul(@ptr, lhs, rhs, name))
		end

		# No unsigned wrap multiplication.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [MulInst] The integer product of the two operands.
		def nuw_mul(lhs, rhs, name = '')
			NUWMulInst.new(Bindings.build_nuw_mul(@ptr, lhs, rhs, name))
		end

		# Division

		# @param [Value]	lhs	Floating point or vector of floating points.
		# @param [Value]	rhs	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FDivInst] The floating point quotient of the two operands.
		def fdiv(lhs, rhs, name = '')
			FDivInst.new(Bindings.build_f_div(@ptr, lhs, rhs, name))
		end

		# Signed integer division.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SDivInst] The integer quotient of the two operands.
		def sdiv(lhs, rhs, name = '')
			SDivInst.new(Bindings.build_s_div(@ptr, lhs, rhs, name))
		end

		# Signed exact integer division.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SDivInst] The integer quotient of the two operands.
		def exact_sdiv(lhs, rhs, name = '')
			ExactSDivInst.new(Bindings.build_exact_s_div(@ptr, lhs, rhs, name))
		end

		# Unsigned integer division.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SDivInst] The integer quotient of the two operands.
		def udiv(lhs, rhs, name = '')
			UDivInst.new(Bindings.build_u_div(@ptr, lhs, rhs, name))
		end

		# Remainder

		# @param [Value]	lhs	Floating point or vector of floating points.
		# @param [Value]	rhs	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FRemInst] The floating point remainder.
		def frem(lhs, rhs, name = '')
			FRemInst.new(Bindings.build_f_rem(@ptr, lhs, rhs, name))
		end

		# Signed remainder.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SRemInst] The integer remainder.
		def srem(lhs, rhs, name = '')
			SRemInst.new(Bindings.build_s_rem(@ptr, lhs, rhs, name))
		end

		# Unsigned remainder.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SRemInst] The integer remainder.
		def urem(lhs, rhs, name = '')
			URemInst.new(Bindings.build_u_rem(@ptr, lhs, rhs, name))
		end

		# Negation

		# Integer negation. Implemented as a shortcut to the equivalent sub
		# instruction.
		#
		# @param [Value]	val	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NegInst] The negated operand.
		def neg(val, name = '')
			NegInst.new(Bindings.build_neg(@ptr, val, name))
		end

		# Floating point negation. Implemented as a shortcut to the
		# equivalent sub instruction.
		#
		# @param [Value]	val	Floating point or vector of floating points.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NegInst] The negated operand.
		def fneg(val, name = '')
			FNegInst.new(Bindings.build_f_neg(@ptr, val, name))
		end

		# No signed wrap integer negation. Implemented as a shortcut to the
		# equivalent sub instruction.
		#
		# @param [Value]	val	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NegInst] The negated operand.
		def nsw_neg(val, name = '')
			NSWNegInst.new(Bindings.build_nsw_neg(@ptr, val, name))
		end

		# No unsigned wrap integer negation. Implemented as a shortcut to the
		# equivalent sub instruction.
		#
		# @param [Value]	val	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NegInst] The negated operand.
		def nuw_neg(val, name = '')
			NUWNegInst.new(Bindings.build_nuw_neg(@ptr, val, name))
		end

		######################
		# Bitwise Operations #
		######################

		# A wrapper method around the {#shift_left} and {#shift_right}
		# methods.
		#
		# @param [:left, :right]			dir	The direction to shift.
		# @param [Value]				lhs	Integer or vector of integers.
		# @param [Value]				rhs	Integer or vector of integers.
		# @param [:arithmetic, :logical]	mode	Shift mode for right shifts.
		# @param [String]				name	Name of the result in LLVM IR.
		#
		# @return [LeftShiftInst, ARightShiftInst, LRightShiftInst] An integer instruction.
		def shift(dir, lhs, rhs, mode = :arithmetic, name = '')
			case dir
			when :left	then shift_left(lhs, rhs, name)
			when :right	then shift_right(lhs, rhs, mode, name)
			end
		end

		# @param [Value]	lhs	Integer or vector of integers
		# @param [Value]	rhs	Integer or vector of integers
		# @param [String]	name	Name of the result in LLVM IR
		#
		# @return [LeftShiftInst] An integer instruction.
		def shift_left(lhs, rhs, name = '')
			LeftShiftInst.new(Bindings.build_shl(@ptr, lhs, rhs, name))
		end
		alias :shl :shift_left

		# A wrapper function around {#ashr} and {#lshr}.
		#
		# @param [Value]				lhs	Integer or vector of integers
		# @param [Value]				rhs	Integer or vector of integers
		# @param [:arithmetic, :logical]	mode The filling mode.
		# @param [String]				name	Name of the result in LLVM IR
		#
		# @return [LeftShiftInst] An integer instruction.
		def shift_right(lhs, rhs, mode = :arithmetic, name = '')
			case mode
			when :arithmetic	then ashr(lhs, rhs, name)
			when :logical		then lshr(lhs, rhs, name)
			end
		end

		# Arithmetic (sign extended) shift right.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [ARightShiftInst] An integer instruction.
		def ashr(lhs, rhs, name = '')
			ARightShiftInst.new(Bindings.build_a_shr(@ptr, lhs, rhs, name))
		end

		# Logical (zero fill) shift right.
		#
		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [ARightShiftInst] An integer instruction.
		def lshr(lhs, rhs, name = '')
			LRightShiftInst.new(Bindings.build_l_shr(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [AndInst] An integer instruction.
		def and(lhs, rhs, name = '')
			AndInst.new(Bindings.build_and(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [OrInst] An integer instruction.
		def or(lhs, rhs, name = '')
			OrInst.new(Bindings.build_or(@ptr, lhs, rhs, name))
		end

		# @param [Value]	lhs	Integer or vector of integers.
		# @param [Value]	rhs	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [XOrInst] An integer instruction.
		def xor(lhs, rhs, name = '')
			XOrInst.new(Bindings.build_xor(@ptr, lhs, rhs, name))
		end

		# Boolean negation.
		#
		# @param [Value]	val	Integer or vector of integers.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [NotInst] An integer instruction.
		def not(val, name = '')
			NotInst.new(Bindings.build_not(@ptr, val, name))
		end

		#####################
		# Memory Management #
		#####################

		# Heap allocation.
		#
		# @param [Type]	type Type or value whose type should be malloced.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [MallocInst] A pointer to the malloced bytes.
		def malloc(type, name = '')
			MallocInst.new(Bindings.build_malloc(@ptr, check_type(type), name))
		end

		# Heap array allocation.
		#
		# @param [Type]	type Type or value whose type will be the element type of the malloced array.
		# @param [Value]	size Unsigned integer representing size of the array.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [ArrayMallocInst] A pointer to the malloced array
		def array_malloc(type, size, name = '')
			ArrayMallocInst.new(Bindings.build_array_malloc(@ptr, check_cg_type(type), size, name))
		end

		# Stack allocation.
		#
		# @param [Type]	type	Type or value whose type should be allocad.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [AllocaInst] A pointer to the allocad bytes.
		def alloca(type, name = '')
			AllocaInst.new(Bindings.build_alloca(@ptr, check_cg_type(type), name))
		end

		# Stack array allocation.
		#
		# @param [Type]	type	Type or value whose type should be allocad.
		# @param [Value]	size Unsigned integer representing size of the array.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [ArrayAllocaInst] A pointer to the allocad bytes.
		def array_alloca(type, size, name = '')
			ArrayAllocaInst.new(Bindings.build_array_alloca(@ptr, check_cg_type(type), size, name))
		end

		# @param [LLVM::Value] ptr The pointer to be freed.
		#
		# @return [FreeInst] The result of the free instruction.
		def free(ptr)
			FreeInst.new(Bindings.build_free(@ptr, ptr))
		end

		# Load the value of a given pointer.
		#
		# @param [Value]	ptr	Pointer to be loaded.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [LoadInst] The result of the load operation. Represents a value of the pointer's type.
		def load(ptr, name = '')
			LoadInst.new(Bindings.build_load(@ptr, ptr, name))
		end

		# Store a value at a given pointer.
		#
		# @param [Value] val The value to be stored.
		# @param [Value] ptr Pointer to the same type as val.
		#
		# @return [StoreInst] The result of the store operation.
		def store(val, ptr)
			StoreInst.new(Bindings.build_store(@ptr, val, ptr))
		end

		# Obtain a pointer to the element at the given indices.
		#
		# @param [Value]		ptr		Pointer to an aggregate value
		# @param [Array<Value>]	indices	Ruby array of Value representing
		#   indices into the aggregate.
		# @param [String]		name		The name of the result in LLVM IR.
		#
		# @return [GetElementPtrInst] The resulting pointer.
		def get_element_ptr(ptr, indices, name = '')
			check_array_type(indices, Value, 'indices')

			indices_ptr = FFI::MemoryPointer.new(:pointer, indices.length)
			indices_ptr.write_array_of_pointer(indices)

			GetElementPtrInst.new(Bindings.build_gep(@ptr, ptr, indices_ptr, indices.length, name))
		end
		alias :gep :get_element_ptr

		# Builds a in-bounds getelementptr instruction. If the indices are
		# outside the allocated pointer the value is undefined.
		#
		# @param [Value]		ptr		Pointer to an aggregate value
		# @param [Array<Value>]	indices	Ruby array of Value representing
		#   indices into the aggregate.
		# @param [String]		name		The name of the result in LLVM IR.
		#
		# @return [InBoundsGEPInst] The resulting pointer.
		def get_element_ptr_in_bounds(ptr, indices, name = '')
			check_array_type(indices, Value, 'indices')

			indices_ptr = FFI::MemoryPointer.new(:pointer, indices.length)
			indices_ptr.write_array_of_pointer(indices)

			InBoundsGEPInst.new(Bindings.build_in_bounds_gep(@ptr, ptr, indices_ptr, indices.length, name))
		end
		alias :inbounds_gep :get_element_ptr_in_bounds

		# Builds a struct getelementptr instruction.
		#
		# @param [Value]	ptr		Pointer to a structure.
		# @param [Value]	index	Unsigned integer representing the index of a structure member.
		# @param [String]	name		Name of the result in LLVM IR.
		#
		# @return [StructGEPInst] The resulting pointer.
		def struct_get_element_ptr(ptr, index, name = '')
			StructGEPInst.new(Bindings.build_struct_gep(@ptr, ptr, index, name))
		end
		alias :struct_getp :struct_get_element_ptr

		# Creates a global string initialized to a given value.
		#
		# @param [String] string	String used by the initialize.
		# @param [String] name	Name of the result in LLVM IR.
		#
		# @return [GlobalStringInst] Reference to the global string.
		def global_string(string, name = '')
			GlobalStringInst.new(Bindings.build_global_string(@ptr, string, name))
		end

		# Creates a pointer to a global string initialized to a given value.
		#
		# @param [String] string	String used by the initializer
		# @param [String] name	Name of the result in LLVM IR
		#
		# @return [GlobalStringPtrInst] Reference to the global string pointer.
		def gloabl_string_pointer(string, name = '')
			GlobalStringPtrInst.new(Bindings.build_global_string_ptr(@ptr, string, name))
		end

		#######################
		# Atomic Instructions #
		#######################

		# Create an atomic read/modify/write instruction.
		#
		# @see http://llvm.org/docs/LangRef.html#atomic-memory-ordering-constraints
		#
		# @param [Symbol from _enum_atomic_rmw_bin_op_]  op             Operation to perform
		# @param [OpaqueValue]                           addr           Address to modify
		# @param [OpaqueValue]                           val            Value to test
		# @param [Symbol from _enum_atomic_ordering_]    ordering       Memory ordering constraints
		# @param [Boolean]                               single_thread  Synchronize with single thread or all threads
		#
		# @return [AtomicRMWInst]
		def atomic_rmw(op, addr, val, ordering, single_thread)
			AtomicRMWInst.new(Bindings.build_atomic_rmw(@ptr, op, addr, val, ordering, single_thread.to_i))
		end

		###############################
		# Type and Value Manipulation #
		###############################

		# Cast a value to a given address space.
		#
		# @param [Value]  val   Value to cast
		# @param [Type]   type  Target type
		# @param [String] name  Name of the result in LLVM IR
		#
		# @return [AddrSpaceCastInst]
		def addr_space_cast(val, type, name = '')
			AddrSpaceCast.new(Bindings.addr_space_cast(@ptr, val, check_cg_type(type), name))
		end

		# Cast a value to the given type without changing any bits.
		#
		# @param [Value]   val   Value to cast
		# @param [Type]    type  Target type
		# @param [String]  name  Name of the result in LLVM IR
		#
		# @return [BitCastInst] A value of the target type.
		def bitcast(val, type, name = '')
			BitCastInst.new(Bindings.build_bit_cast(@ptr, val, check_cg_type(type), name))
		end

		# @param [Value]	val	Value to cast.
		# @param [Type]	type	Target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FPCastInst] A value of the target type.
		def floating_point_cast(val, type, name = '')
			FPCastInst.new(Bindings.build_fp_cast(@ptr, val, check_cg_type(type), name))
		end
		alias :fp_cast :floating_point_cast

		# Extend a floating point value.
		#
		# @param [Value]	val	Floating point or vector of floating point.
		# @param [Type]	type	Floating point or vector of floating point type of greater size than val's type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FPExtendInst] The extended value.
		def floating_point_extend(val, type, name = '')
			FPExtendInst.new(Bindings.build_fp_ext(@ptr, val, check_cg_type(type), name))
		end
		alias :fp_ext :floating_point_extend
		alias :fp_extend :floating_point_extend

		# Convert a floating point to a signed integer.
		#
		# @param [Value]	val	Floating point or vector of floating points to convert.
		# @param [Type]	type	Integer or vector of integer target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FPToSIInst] The converted value.
		def floating_point_to_signed_int(val, type, name = '')
			FPToSIInst.new(Bindings.build_fp_to_si(@ptr, val, check_cg_type(type), name))
		end
		alias :fp2si :floating_point_to_signed_int

		# Convert a floating point to an unsigned integer.
		#
		# @param [Value]	val	Floating point or vector of floating points to convert.
		# @param [Type]	type	Integer or vector of integer target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [FPToSIInst] The converted value.
		def floating_point_to_unsigned_int(val, type, name = '')
			FPToUIInst.new(Bindings.build_fp_to_ui(@ptr, val, check_cg_type(type), name))
		end
		alias :fp2ui :floating_point_to_unsigned_int

		# Truncate a floating point value.
		#
		# @param [Value]	val	Floating point or vector of floating point.
		# @param [Type]	type	Floating point or vector of floating point type of lesser size than val's type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [LLVM::Instruction] The truncated value
		def floating_point_truncate(val, type, name = '')
			FPTruncInst.new(Bindings.build_fp_trunc(@ptr, val, check_cg_type(type), name))
		end
		alias :fp_trunc :floating_point_truncate
		alias :fp_truncate :floating_point_truncate

		# Cast an int to a pointer.
		#
		# @param [Value]	val	An integer value.
		# @param [Type]	type	A pointer type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [IntToPtrInst] A pointer of the given type and the address held in val.
		def int_to_ptr(val, type, name = '')
			IntToPtrInst.new(Bindings.build_int_to_ptr(@ptr, val, check_cg_type(type), name))
		end
		alias :int2ptr :int_to_ptr

		# @param [Value]	val	An integer value.
		# @param [Type]	type Integer or vector of integer target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [IntCastInst]
		def integer_cast(val, type, name = '')
			IntCastInst.new(Bindings.build_int_cast(@ptr, val, check_cg_type(type), name))
		end
		alias :int_cast :integer_cast

		# @param [Value]	val	A pointer value.
		# @param [Type]	type A pointer target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [PtrCastInst]
		def ptr_cast(val, type, name = '')
			PtrCastInst.new(Bindings.build_pointer_cast(@ptr, val, check_cg_type(type), name))
		end

		# Cast a pointer to an int. Useful for pointer arithmetic.
		#
		# @param [Value]	val	A pointer value.
		# @param [Type]	type	An integer type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [PtrToIntInst] An integer of the given type representing the pointer's address.
		def ptr_to_int(val, type, name = '')
			PtrToIntInst.new(Bindings.build_ptr_to_int(@ptr, val, check_cg_type(type), name))
		end
		alias :ptr2int :ptr_to_int

		# Sign extension by copying the sign bit (highest order bit) of the
		# value until it reaches the bit size of the given type.
		#
		# @param [Value]	val	Integer or vector of integers to be extended.
		# @param [Type]	type	Integer or vector of integer type of greater size than the size of val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SignExtendInst] The extended value.
		def sign_extend(val, type, name = '')
			SignExtendInst.new(Bindings.build_s_ext(@ptr, val, check_cg_type(type), name))
		end
		alias :sext :sign_extend

		# Sign extension or bitcast.
		#
		# @param [Value]	val	Integer or vector of integers to be extended.
		# @param [Type]	type	Integer or vector of integer type of greater size than the size of val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SignExtendOrBitcastInst] The extended or cast value.
		def sign_extend_or_bitcast(val, type, name = '')
			SignExtendOrBitCastInst.new(Bindings.build_s_ext_or_bit_cast(@ptr, val, check_cg_type(type), name))
		end
		alias :sext_or_bitcast :sign_extend_or_bitcast

		# Convert a signed integer to a floating point.
		#
		# @param [Value]	val	Signed integer or vector of signed integer to convert.
		# @param [Type]	type	Floating point or vector of floating point target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SIToFPInst] The converted value.
		def signed_int_to_floating_point(val, type, name = '')
			SIToFPInst.new(Bindings.build_si_to_fp(@ptr, val, check_cg_type(type), name))
		end
		alias :si2fp :signed_int_to_floating_point

		# Truncates its operand to the given type. The size of the value type
		# must be greater than the size of the target type.
		#
		# @param [Value]	val	Integer or vector of integers to be truncated.
		# @param [Type]	type	Integer or vector of integers of equal size to val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [TruncateInst] The truncated value.
		def truncate(val, type, name = '')
			TruncateInst.new(Bindings.build_trunc(@ptr, val, check_cg_type(type), name))
		end
		alias :trunc :truncate

		# Truncates or bitcast.
		#
		# @param [Value]	val	Integer or vector of integers to be truncated.
		# @param [Type]	type	Integer or vector of integers of equal size to val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [TruncateInst] The truncated or cast value.
		def truncate_or_bitcast(val, type, name = '')
			TruncateOrBitCastInst.new(Bindings.build_trunc_or_bit_cast(@ptr, val, check_cg_type(type), name))
		end

		# Convert an unsigned integer to a floating point.
		#
		# @param [Value]	val	Signed integer or vector of signed integer to convert.
		# @param [Type]	type	Floating point or vector of floating point target type.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [SIToFPInst] The converted value.
		def unsigned_int_to_floating_point(val, type, name = '')
			UIToFPInst.new(Bindings.build_ui_to_fp(@ptr, val, check_cg_type(type), name))
		end
		alias :ui2fp :unsigned_int_to_floating_point

		# Zero extends its operand to the given type. The size of the value
		# type must be greater than the size of the target type.
		#
		# @param [Value]	val	Integer or vector of integers to be extended.
		# @param [Type]	type	Integer or vector of integer type of greater size than val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [ZeroExtendInst] The extended value.
		def zero_extend(val, type, name = '')
			ZeroExtendInst.new(Bindings.build_z_ext(@ptr, val, check_cg_type(type), name))
		end
		alias :zext :zero_extend

		# Zero extend or bitcast.
		#
		# @param [Value]	val	Integer or vector of integers to be extended.
		# @param [Type]	type	Integer or vector of integer type of greater size than val.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [ZeroExtendInst] The extended or cast value.
		def zero_extend_or_bitcast(val, type, name = '')
			ZeroExtendOrBitCastInst.new(Bindings.build_z_ext_or_bit_cast(@ptr, val, check_cg_type(type), name))
		end
		alias :zext_or_bitcast :zero_extend_or_bitcast

		###########################
		# Comparison Instructions #
		###########################

		# Builds an icmp instruction. Compares lhs to rhs using the given
		# symbol predicate.
		#
		# @see Bindings._enum_int_predicate_
		# @LLVMInst icmp
		#
		# @param [Symbol]	pred	An integer predicate.
		# @param [Value]	lhs	Left hand side of the comparison, of integer or pointer type.
		# @param [Value]	rhs	Right hand side of the comparison, of the same type as lhs.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [IntCmpInst] A Boolean represented as Int1.
		def int_comparison(pred, lhs, rhs, name = '')
			IntCmpInst.new(Bindings.build_i_cmp(@ptr, pred, lhs, rhs, name))
		end
		alias :icmp :int_comparison

		# Builds an fcmp instruction. Compares lhs to rhs as reals using the
		# given symbol predicate.
		#
		# @see Bindings._enum_real_predicate_
		# @LLVMInst fcmp
		#
		# @param [Symbol]	pred	A real predicate.
		# @param [Value]	lhs	Left hand side of the comparison, of floating point type.
		# @param [Value]	rhs	Right hand side of the comparison, of the same type as lhs.
		# @param [String]	name Name of the result in LLVM IR.
		#
		# @return [FCmpInst] A Boolean represented as an Int1.
		def fp_comparison(pred, lhs, rhs, name = '')
			FCmpInst.new(Bindings.build_f_cmp(@ptr, pred, lhs, rhs, name))
		end
		alias :fcmp :fp_comparison

		# Calculate the difference between two pointers.
		#
		# @param [Value]	lhs	A pointer.
		# @param [Value]	rhs	A pointer.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [PtrDiffInst] The integer difference between the two pointers.
		def ptr_diff(lhs, rhs, name = '')
			PtrDiffInst.new(Bindings.build_ptr_diff(lhs, rhs, name))
		end

		# Check if a value is not null.
		#
		# @param [Value]	val	Value to check.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [LLVM::Instruction] A Boolean represented as an Int1.
		def is_not_null(val, name = '')
			IsNotNullInst.new(Builder.build_is_not_null(@ptr, val, name))
		end

		# Check if a value is null.
		#
		# @param [Value]	val	Value to check.
		# @param [String]	name	Name of the result in LLVM IR.
		#
		# @return [LLVM::Instruction] A Boolean represented as an Int1.
		def is_null(val, name = '')
			IsNullInst.new(Bindings.build_is_null(@ptr, val, name))
		end
	end
end
