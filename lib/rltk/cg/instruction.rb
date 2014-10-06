# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/09
# Description:	This file defines LLVM Instruction classes.

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

	# This class represents LLVM IR instructions.
	class Instruction < User

		# Many of the C functions for interacting with instructions treat
		# all instructions as Instruction objects.  However, some Instruction
		# sub-types can be tested for.  This is a list of those sub-types and
		# the names of their tests.
		TESTABLE = [
			:AddrSpaceCast,
			:Alloca,
			:BitCast,
			:Call,
			:ExtractElement,
			:ExtractValue,
			:FCmp,
			[:FPExtend, :FPExt],
			:FPToSI,
			:FPToUI,
			:FPTrunc,
			:GetElementPtr,
			[:IntCmp, :ICmp],
			:InsertElement,
			:InsertValue,
			:IntToPtr,
			:Invoke,
			:Load,
			:PtrToInt,
			:Return,
			[:SignExtend, :SExt],
			:SIToFP,
			:Select,
			:ShuffleVector,
			:Store,
			:Switch,
			[:Truncate, :Trunc],
			:UIToFP,
			:Unreachable
		]

		# Instantiate an Instruction object from a given pointer.  The type
		# of the instruction is tested and the appropriate sub-type is picked
		# if possible.  If not, a generic Instruction object is returned.
		#
		# @param [FFI::Pointer] ptr Pointer to a C instruction object.
		#
		# @return [Instruction] An Instruction or one of its sub-types.
		def self.from_ptr(ptr)
			match = nil

			TESTABLE.each do |el|
				klass, test =
				if el.is_a?(Symbol)
					[RLTK::CG.const_get("#{el}Inst".to_sym), Bindings.get_bname("IsA#{el}Inst")]

				else
					[RLTK::CG.const_get("#{el.first}Inst".to_sym), Bindings.get_bname("IsA#{el.last}Inst")]
				end

				match = klass if Bindings.send(test, ptr)
			end

			if match then match else Intruction end.new(ptr)
		end

		# You should never instantiate Instruction object directly.  Use the
		# builder class to add new instructions.
		#
		# @param [FFI::Pointer] ptr Pointer to a C instruction object.
		def initialize(ptr)
			@ptr = check_type(ptr, FFI::Pointer, 'ptr')
		end

		# @return [Instruction, nil] Instruction that follows the current one in a {BasicBlock}.
		def next
			if (ptr = Bindings.get_next_instruction(@ptr)).null? then nil else Instruction.from_ptr(ptr) end
		end

		# @return [BasicBlock] BasicBlock that contains this Instruction.
		def parent
			if (ptr = Bindings.get_instruction_parent(@ptr)).null? then nil else BasicBlock.new(ptr) end
		end

		# @return [Instruction, nil] Instruction that precedes the current on in a {BasicBlock}.
		def previous
			if (ptr = Bindings.get_previous_instruction(@ptr)).null? then nil else Instruction.from_ptr(ptr) end
		end

		##########################################
		# Instruction Testing Method Definitions #
		##########################################

		selector	= Regexp.new(/LLVMIsA.*Inst/)
		syms		= Symbol.all_symbols.select { |sym| selector.match(sym.to_s) }

		syms.each do |sym|
			sym = (Bindings.get_bname(sym).to_s + '?').to_sym

			define_method(sym) do
				Bindings.send(sym, @ptr)
			end
		end
	end

	# An Instruction representing a function call.
	#
	# @LLVMInst call
	class CallInst < Instruction
		# Get the calling convention used for this call.
		#
		# @see Bindings._enum_call_conv_
		#
		# @return [Symbol]
		def calling_convention
			Bindings.enum_type(:call_conv)[Bindings.get_instruction_call_conv(@ptr)]
		end

		# Set the calling convention used for this call.
		#
		# @see Bindings._enum_call_conv_
		#
		# @param [Symbol] conv Calling convention to set.
		def calling_convention=(conv)
			Bindings.set_instruction_call_conv(@ptr, Bindings.enum_type(:call_conv)[conv])

			conv
		end

		# @return [Boolean]
		def tail_call?
			Bindings.is_tail_call(@ptr).to_bool
		end

		# Sets the *tail call* property for this call instruction.
		#
		# @param [Boolean]  bool  If this is a tail call or not
		#
		# @return [void]
		def tail_call=(bool)
			Bindings.set_tail_call(@ptr, bool.to_i)
		end
	end

	# An Instruction representing a Phi node.
	#
	# @see http://en.wikipedia.org/wiki/Static_single_assignment_form
	# @LLVMInst phi
	class PhiInst < Instruction
		# @return [IncomingCollection] Proxy object for inspecting the incoming {BasicBlock}/{Value} pairs.
		def incoming
			@incoming_collection ||= IncomingCollection.new(self)
		end

		# This class is used to access a Phi node's incoming {BasicBlock}/{Value} pairs.
		class IncomingCollection
			include Enumerable

			# @param [PhiInst] phi Phi instruction for which this is a proxy.
			def initialize(phi)
				@phi = phi
			end

			# Access the {BasicBlock}/{Value} pair at the given index.
			#
			# @param [Integer] index Index of the desired pair.  May be negative.
			#
			# @return [Array(BasicBlock, Value)]
			def [](index)
				index += self.size if index < 0

				if 0 <= index and index < self.size
					[self.block(index), self.value(index)]
				end
			end

			# Add incoming {BasicBlock}/{Value} pairs to a Phi node.
			#
			# @example Adding a single block/value pair:
			#    phi.incoming.add(bb, val)
			#
			# @example Adding several block/value pairs:
			#    phi.incoming.add({bb0 => val0, bb1 => val1})
			#
			# @param [BasicBlock, Hash{BasicBlock => Value}]	overloaded
			# @param [Value, nil]						value
			#
			# @return [void]
			def add(overloaded, value = nil)
				blks, vals =
				if overloaded.is_a?(BasicBlock) and check_type(value, Value, 'value')
					[overloaded, value]
				else
					if RUBY_VERSION[0..2] == '1.9'
						[overloaded.keys, overloaded.values]
					else
						[(keys = overloaded.keys), overloaded.values_at(*keys)]
					end
				end

				vals_ptr = FFI::MemoryPointer.new(:pointer, vals.size)
				vals_ptr.write_array_of_pointer(vals)

				blks_ptr = FFI::MemoryPointer.new(:pointer, blks.size)
				blks_ptr.write_array_of_pointer(blks)

				nil.tap { Bindings.add_incoming(@phi, vals_ptr, blks_ptr, vals.length) }
			end
			alias :<< :add

			# @param [Integer] index Index of desired incoming {BasicBlock}.
			#
			# @return [BasicBlock] Incoming {BasicBlock}.
			def block(index)
				index += self.size if index < 0

				if 0 <= index and index < self.size
					BasicBlock.new(Bindings.get_incoming_block(@phi, index))
				end
			end

			# An iterator for each incoming {BasicBlock}/{Value} pair.
			#
			# @yieldparam pair [Array(BasicBlock, Value)]
			#
			# @return [Enumerator] Returns an Enumerator if no block is given.
			def each
				return to_enum(:each) unless block_given?

				self.size.times { |index| yield self[index] }

				self
			end

			# @return [Integer] Number of incoming {BasicBlock}/{Value} pairs.
			def size
				Bindings.count_incoming(@phi)
			end

			# @param [Integer] index Index of desired incoming {Value}.
			#
			# @return [BasicBlock] Incoming {Value}.
			def value(index)
				index += self.size if index < 0

				if 0 <= index and index < self.size
					Value.new(Bindings.get_incoming_value(@phi, index))
				end
			end
		end
	end

	# An Instruction representing a conditional jump with multiple cases.
	#
	# @LLVMInst switch
	class SwitchInst < Instruction
		# Add a case to this conditional jump.
		#
		# @param [Value]		val		Value for this case.
		# @param [BasicBlock]	block	BasicBlock to jump to if this case is matched.
		#
		# @return [void]
		def add_case(val, block)
			Bindings.add_case(@ptr, val, block)
		end
	end

	#############################
	# Empty Instruction Classes #
	#############################

	# @LLVMInst add
	class AddInst                 < Instruction; end

	# @LLVMInst addr_space_cast
	class AddrSpaceCastInst       < Instruction; end

	# @LLVMInst alloca
	class AllocaInst              < Instruction; end

	# @LLVMInst and
	class AndInst                 < Instruction; end

	# @LLVMInst ashr
	class ARightShiftInst         < Instruction; end

	# @LLVMInst alloca
	class ArrayAllocaInst         < Instruction; end

	class ArrayMallocInst         < Instruction; end

	# @LLVMInst atomicrmw
	class AtomicRMWInst           < Instruction; end

	# @LLVMInst bitcast
	class BitCastInst             < Instruction; end

	# @LLVMInst br
	class BranchInst              < Instruction; end

	# @LLVMInst br
	class CondBranchInst          < Instruction; end

	# @LLVMInst sdiv
	class ExactSDivInst           < Instruction; end

	# @LLVMInst extractelement
	class ExtractElementInst      < Instruction; end

	# @LLVMInst extractvalue
	class ExtractValueInst        < Instruction; end

	# @LLVMInst fadd
	class FAddInst                < Instruction; end

	# @LLVMInst fcmp
	class FCmpInst                < Instruction; end

	# @LLVMInst fdiv
	class FDivInst                < Instruction; end

	# @LLVMInst fmul
	class FMulInst                < Instruction; end

	# @LLVMInst fsub
	class FNegInst                < Instruction; end

	# @LLVMInst fptosi
	class FPToSIInst              < Instruction; end

	# @LLVMInst fptoui
	class FPToUIInst              < Instruction; end

	class FPCastInst              < Instruction; end

	# @LLVMInst fpext
	class FPExtendInst            < Instruction; end

	# @LLVMInst fptrunc
	class FPTruncInst             < Instruction; end

	class FreeInst                < Instruction; end

	# @LLVMInst frem
	class FRemInst                < Instruction; end

	# @LLVMInst fsub
	class FSubInst                < Instruction; end

	# @LLVMInst gep
	# @see http://llvm.org/docs/GetElementPtr.html
	class GetElementPtrInst       < Instruction; end

	class GlobalStringInst        < Instruction; end
	class GlobalStringPtrInst     < Instruction; end

	# @LLVMInst gep
	# @see http://llvm.org/docs/GetElementPtr.html
	class InBoundsGEPInst         < Instruction; end

	# @LLVMInst insertelement
	class InsertElementInst       < Instruction; end

	# @LLVMInst insertvalue
	class InsertValueInst         < Instruction; end

	# @LLVMInst inttoptr
	class IntToPtrInst            < Instruction; end

	class IntCastInst             < Instruction; end

	# @LLVMInst icmp
	class IntCmpInst              < Instruction; end

	# @LLVMInst invoke
	class InvokeInst              < Instruction; end

	class IsNotNullInst           < Instruction; end
	class IsNullInstInst          < Instruction; end

	# @LLVMInst shl
	class LeftShiftInst           < Instruction; end

	# @LLVMInst load
	class LoadInst                < Instruction; end

	# @LLVMInst lshr
	class LRightShiftInst         < Instruction; end

	class MallocInst              < Instruction; end

	# @LLVMInst mul
	class MulInst                 < Instruction; end

	# @LLVMInst sub
	class NegInst                 < Instruction; end

	class NotInst                 < Instruction; end

	# @LLVMInst add
	class NSWAddInst              < Instruction; end

	# @LLVMInst mul
	class NSWMulInst              < Instruction; end

	# @LLVMInst sub
	class NSWNegInst              < Instruction; end

	# @LLVMInst sub
	class NSWSubInst              < Instruction; end

	# @LLVMInst add
	class NUWAddInst              < Instruction; end

	# @LLVMInst mul
	class NUWMulInst              < Instruction; end

	# @LLVMInst sub
	class NUWNegInst              < Instruction; end

	# @LLVMInst sub
	class NUWSubInst              < Instruction; end

	# @LLVMInst or
	class OrInst                  < Instruction; end

	# @LLVMInst ptrtoint
	class PtrToIntInst            < Instruction; end

	class PtrCastInst             < Instruction; end
	class PtrDiffInst             < Instruction; end

	# @LLVMInst ret
	class ReturnInst              < Instruction; end

	# @LLVMInst ret
	class ReturnAggregateInst     < Instruction; end

	# @LLVMInst ret
	class ReturnVoidInst          < Instruction; end

	# @LLVMInst sdiv
	class SDivInst                < Instruction; end

	# @LLVMInst select
	class SelectInst              < Instruction; end

	# @LLVMInst shufflevector
	class ShuffleVectorInst       < Instruction; end

	# @LLVMInst sext
	class SignExtendInst          < Instruction; end

	# @LLVMInst sext
	# @LLVMInst bitcast
	class SignExtendOrBitCastInst < Instruction; end

	# @LLVMInst sitofp
	class SIToFPInst              < Instruction; end

	# @LLVMInst srem
	class SRemInst                < Instruction; end

	# @LLVMInst store
	class StoreInst               < Instruction; end

	# @LLVMInst gep
	# @see http://llvm.org/docs/GetElementPtr.html
	class StructGEPInst           < Instruction; end

	# @LLVMInst sub
	class SubInst                 < Instruction; end

	# @LLVMInst trunc
	class TruncateInst            < Instruction; end

	# @LLVMInst trunc
	# @LLVMInst bitcast
	class TruncateOrBitCastInst   < Instruction; end

	# @LLVMInst udiv
	class UDivInst                < Instruction; end

	# @LLVMInst uitofp
	class UIToFPInst              < Instruction; end

	# @LLVMInst unreachable
	class UnreachableInst         < Instruction; end

	# @LLVMInst urem
	class URemInst                < Instruction; end

	# @LLVMInst xor
	class XOrInst                 < Instruction; end

	# @LLVMInst zext
	class ZeroExtendInst          < Instruction; end

	# @LLVMInst zext
	# @LLVMInst bitcast
	class ZeroExtendOrBitCastInst < Instruction; end
end
