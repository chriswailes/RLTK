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
	class Instruction < User
		TESTABLE = [
			:Alloca,
			:BitCast,
			:Call,
			:ExtractElement,
			:ExtractValue,
			:FPCmp,
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
		
		def self.from_ptr(ptr)
			match = nil
			
			TESTABLE.each do |el|
				klass, test =
				if el.is_a?(Symbol)
					RLTK::CG.const_get("#{el}Inst".to_sym), Bindings.get_bname("IsA#{el}Inst")
					
				else
					RLTK::CG.const_get("#{el.first}Inst".to_sym), Bindings.get_bname("IsA#{el.last}Inst")
				end
				
				match = klass if Bindings.send(test, ptr)
			end
			
			if match then match else Intruction end.new(ptr)
		end
		
		# You should never instantiate Instruction object directly.  Use the
		# builder class to add new instructions.
		def initialize(ptr)
			@ptr = check_type(ptr, FFI::Pointer, 'ptr')
		end
		
		def next
			if (ptr = Bindings.get_next_instruction(@ptr)).null? then nil else Instruction.from_ptr(ptr) end
		end
		
		def parent
			if (ptr = Bindings.get_instruction_parent(@ptr)).null? then nil else BasicBlock.new(ptr) end
		end
		
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
			
			define_method(sym)
				Bindings.send(sym, @ptr)
			end
		end
	end
	
	class CallInst < Instruction
		def calling_convention
			Bindings.get_instruction_call_conv(@ptr)
		end
		
		def calling_convention=(conv)
			Bindings.set_instruction_call_conv(@ptr, conv)
			
			conv
		end	
	end
	
	class PhiInst < Instruction
		def incoming
			@incoming_collection ||= IncomingCollection.new(self)
		end
		
		class IncomingCollection
			include Enumerable
			
			def initialize(phi)
				@phi = phi
			end
			
			def [](index)
				limit = if index < 0 then self.size + index else self.size end
				
				if 0 <= index and index < limit
					[self.block(index), self.value(index)]
				end
			end
			
			def add(overloaded, value = nil)
				blks, vals =
				if overloaded.is_a?(BasicBlock) and check_type(value, Value, 'value')
					overloaded, value
				else
					if RUBY_VERSION[0..2] == "1.9"
						overloaded.keys, overloaded.values
					else
						(keys = overloaded.keys), overloaded.values_at(*keys)
					end
				end
				
				FFI::MemoryPointer.new(:pointer, incoming.size) do |vals_ptr|
				
					vals_ptr.write_array_of_pointers(vals)
				
					FFI::MemoryPointer.new(:pointer, incoming.size) do |blks_ptr|
						blks_ptr.write_array_of_pointers(blks)
					
						Bindings.add_incoming(@ptr, vals_ptr, blks_ptr, vals.length)
					end
				end
			
				nil
			end
			alias :<< :add
			
			def block(index)
				limit = if index < 0 then self.size + index else self.size end
				
				if 0 <= index and index < limit
					BasicBlock.new(Bindings.get_incoming_block(@phi, index))
				end
			end
			
			def each
				return to_enum(:each) unless block_given?
				
				self.size.times { |index| yield self[index] }
				
				self
			end
			
			def size
				Bindings.count_incoming(@phi)
			end
			
			def value(index)
				limit = if index < 0 then self.size + index else self.size end
				
				if 0 <= index and index < limit
					Value.new(Bindings.get_incoming_value(@phi, index))
				end
			end
		end
	end
	
	class SwitchInst < Instruction
		def add_case(val, block)
			Bindings.add_case(@ptr, val, block)
		end
	end
	
	# Empty Instruction Classes
	
	class AddInst				< Instruction; end
	class AllocaInst			< Instruction; end
	class AndInst				< Instruction; end
	class ARightShiftInst		< Instruction; end
	class ArrayAllocaInst		< Instruction; end
	class ArrayMallocInst		< Instruction; end
	class BitCastInst			< Instruction; end
	class BranchInst			< Instruction; end
	class CondBranchInst		< Instruction; end
	class ExactSDivInst			< Instruction; end
	class ExtractElementInst		< Instruction; end
	class ExtractValueInst		< Instruction; end
	class FAddInst				< Instruction; end
	class FDivInst				< Instruction; end
	class FMulInst				< Instruction; end
	class FNegInst				< Instruction; end
	class FPToSIInst			< Instruction; end
	class FPToUIInst			< Instruction; end
	class FPCastInst			< Instruction; end
	class FPCmpInst			< Instruction; end
	class FPExtendInst			< Instruction; end
	class FPTruncInst			< Instruction; end
	class FreeInst				< Instruction; end
	class FRemInst				< Instruction; end
	class FSubInst				< Instruction; end
	class GetElementPtrInst		< Instruction; end
	class GlobalStringInst		< Instruction; end
	class GlobalStringPtrInst	< Instruction; end
	class InBoundsGEPInst		< Instruction; end
	class InsertElementInst		< Instruction; end
	class InsertValueInst		< Instruction; end
	class IntToPtrInst			< Instruction; end
	class IntCastInst			< Instruction; end
	class IntCmpInst			< Instruction; end
	class InvokeInst			< Instruction; end
	class IsNotNullInst			< Instruction; end
	class IsNullInstInst		< Instruction; end
	class LeftShiftInst			< Instruction; end
	class LoadInst				< Instruction; end
	class LRightShiftInst		< Instruction; end
	class MallocInst			< Instruction; end
	class MulInst				< Instruction; end
	class NegInst				< Instruction; end
	class NotInst				< Instruction; end
	class NSWAddInst			< Instruction; end
	class NSWMulInst			< Instruction; end
	class NSWNegInst			< Instruction; end
	class NSWSubInst			< Instruction; end
	class NUWAddInst			< Instruction; end
	class NUWMulInst			< Instruction; end
	class NUWNegInst			< Instruction; end
	class NUWSubInst			< Instruction; end
	class OrInst				< Instruction; end
	class PtrToIntInst			< Instruction; end
	class PtrCastInst			< Instruction; end
	class PtrDiffInst			< Instruction; end
	class ReturnInst			< Instruction; end
	class ReturnAggregateInst	< Instruction; end
	class ReturnVoidInst		< Instruction; end
	class SDivInst				< Instruction; end
	class SelectInst			< Instruction; end
	class ShuffleVectorInst		< Instruction; end
	class SignExtendInst		< Instruction; end
	class SignExtendOrBitCastInst	< Instruction; end
	class SIToFPInst			< Instruction; end
	class SRemInst				< Instruction; end
	class StoreInst			< Instruction; end
	class StructGEPInst			< Instruction; end
	class SubInst				< Instruction; end
	class TruncateInst			< Instruction; end
	class TruncateOrBitCastInst	< Instruction; end
	class UDivInst				< Instruction; end
	class UIToFPInst			< Instruction; end
	class UnreachableInst		< Instruction; end
	class URemInst				< Instruction; end
	class XOrInst				< Instruction; end
	class ZeroExtendInst		< Instruction; end
	class ZeroExtendOrBitCastInst	< Instruction; end
end
