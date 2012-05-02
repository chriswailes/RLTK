# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Builder class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Builder
		include BindingClass
		
		def self.global
			@@global_builder ||= Builder.new
		end
		
		def initialize(block = nil)
			@ptr = Bindings.create_builder
			
			position_at_end(block) if block
		end
		
		def dispose
			if @ptr
				Bindings.dispose_builder(@ptr)
				@ptr = nil
			end
		end
		
		# Create an alias to instance_exec to facilitate building lots of
		# instructions easily.
		alias :build :instance_exec
		
		def build_inst(inst, *args)
			self.send(inst.to_sym, *args)
		end
		alias :'<<' :build_inst
		
		def position(block, instruction)
			raise 'Block must not be nil.' if block.nil?
			raise 'Instruction must not be nil.' if instruction.nil?
			
			Bindings.position_builder(@ptr, block, instruction)
			self
		end
		
		def position_at_end(block)
			raise 'Block must not be nil.' if block.nil?
			
			Bindings.position_builder_at_end(@ptr, block)
			self
		end
		
		def position_before(instruction)
			raise 'Instruction must not be nil.' if instruction.nil?
			
			Bindings.position_builder_before(@ptr, instruction)
			self
		end
		
		################################
		# Instruction Building Methods #
		################################
		
		#################
		# Miscellaneous #
		#################
		
		def current_block
			BasicBlock.new(Bindings.get_insert_block(@ptr))
		end
		alias :insertion_block :current_block
		
		def unreachable
			UnreachableInst.new(Bindings.build_unreachable(@ptr))
		end
		
		###########
		# Returns #
		###########
		
		def ret(val)
			ReturnInst.new(Bindings.build_ret(@ptr, val))
		end
		
		def ret_void
			ReturnVoidInst.new(Bindings.build_ret_void(@ptr))
		end
		
		def ret_aggregate(*vals)
			vals = vals.first if vals.length == 1 and vals.first.instance_of?(::Array)
			
			FFI::MemoryPointer.new(FFI.type_size(:pointer) * vals.length) do |vals_ptr|
				vals_ptr.write_array_of_pointers(vals)
				
				ReturnAggregateInst.new(Bindings.build_aggregate_ret(@ptr, vals_ptr, vals.length))
			end
		end
		
		################
		# Control Flow #
		################
		
		def branch(block)
			BranchInst.new(Bindings.build_br(@ptr, block))
		end
		alias :br :branch
		
		def call(fun, *args)
			name = if args.last.is_a?(String) then args.pop else '' end
			
			FFI::MemoryPointer.new(FFI.type_size(:pointer) * args.length) do |args_ptr|
				args_ptr.write_array_of_pointers(args)
				
				CallInst.new(Bindings.build_call(@ptr, fun, args_ptr, args.length, name))
			end
		end
		
		def cond_branch(block, iftrue, iffalse)
			CondBranchInst.new(Bindings.build_cond_br(@ptr, cond, iftrue, iffalse))
		end
		alias :cond :cond_branch
		
		def extract_element(vector, index, name = '')
			ExtractElementInst.new(Bindings.build_extract_element(@ptr, vector, index, name))
		end
		
		def extract_value(aggregate, index, name = '')
			ExtractValueInst.new(Bindings.build_extract_value(@ptr, aggregate, index, name))
		end
		
		def insert_element(vector, element, index, name = '')
			InsertElementInst.new(Bindings.build_insert_element(@ptr, vector, element, index, name))
		end
		
		def insert_value(aggregate, val, index, name = '')
			InsertValueInst.new(Bindings.build_insert_value(@ptr, aggregate, val, index, name))
		end
		
		def invoke(fun, args, normal, exception, name = '')
			InvokeInst.new(Bindings.build_invoke(@ptr, fun, args, args.length, normal, exception, name))
		end
		
		def phi(type, incoming, name = '')
			returning PhiInst.new(Bindings.build_phi(@ptr, check_type(type), name)) do |phi|
				phi.add_incoming(incoming)
			end
		end
		
		def select(if_val, then_val, else_val, name = '')
			SelectInst.new(Bindings.build_select(@ptr, if_val, then_val, else_val, name))
		end
		
		def shuffle_vector(vec1, vec2, mask, name = '')
			ShuffleVectorInst.new(Bindings.build_shuffle_vector(@ptr, vec1, vec2, mask, name))
		end
		
		def switch(val, default, cases)
			returning SwitchInst.new(Bindings.build_switch(@ptr, val, default, cases.size)) do |inst|
				cases.each { |val, block| inst.add_case(val, block) }
			end
		end
		
		########
		# Math #
		########
		
		# Addition
		
		def add(lhs, rhs, name = '')
			AddInst.new(Bindings.build_add(@ptr, lhs, rhs, name))
		end
		
		def fadd(lhs, rhs, name = '')
			FAddInst.new(Bindings.build_f_add(@ptr, lhs, rhs, name))
		end
		
		def nsw_add(lhs, rhs, name = '')
			NSWAddInst.new(Bindings.build_nsw_add(@ptr, lhs, rhs, name))
		end
		
		def nuw_add(lhs, rhs, name = '')
			NUWAddInst.new(Bindings.build_nuw_add(@ptr, lhs, rhs, name))
		end
		
		# Subtraction
		
		def sub(lhs, rhs, name = '')
			SubInst.new(Bindings.build_sub(@ptr, lhs, rhs, name))
		end
		
		def fsub(lhs, rhs, name = '')
			FSubInst.new(Bindings.build_f_sub(@ptr, lhs, rhs, name))
		end
		
		def nsw_sub(lhs, rhs, name = '')
			NSWSubInst.new(Bindings.build_nsw_sub(@ptr, lhs, rhs, name))
		end
		
		def nuw_sub(lhs, rhs, name = '')
			NUWSubInst.new(Bindings.build_nuw_sub(@ptr, lhs, rhs, name))
		end
		
		# Multiplication
		
		def mul(lhs, rhs, name = '')
			MulInst.new(Bindings.build_mul(@ptr, lhs, rhs, name))
		end
		
		def fmul(lhs, rhs, name = '')
			FMulInst.new(Bindings.build_f_mul(@ptr, lhs, rhs, name))
		end
		
		def nsw_mul(lhs, rhs, name = '')
			NSWMulInst.new(Bindings.build_nsw_mul(@ptr, lhs, rhs, name))
		end
		
		def nuw_mul(lhs, rhs, name = '')
			NUWMulInst.new(Bindings.build_nuw_mul(@ptr, lhs, rhs, name))
		end
		
		# Division
		
		def fdiv(lhs, rhs, name = '')
			FDivInst.new(Bindings.build_f_div(@ptr, lhs, rhs, name))
		end
		
		def sdiv(lhs, rhs, name = '')
			SDivInst.new(Bindings.build_s_div(@ptr, lhs, rhs, name))
		end
		
		def exact_sdiv(lhs, rhs, name = '')
			ExactSDivInst.new(Bindings.build_exact_s_div(@ptr, lhs, rhs, name))
		end
		
		def udiv(lhs, rhs, name = '')
			UDivInst.new(Bindings.build_u_div(@ptr, lhs, rhs, name))
		end
		
		# Remainder
		
		def frem(lhs, rhs, name = '')
			FRemInst.new(Bindings.build_f_rem(@ptr, lhs, rhs, name))
		end
		
		def srem(lhs, rhs, name = '')
			SRemInst.new(Bindings.build_s_rem(@ptr, lhs, rhs, name))
		end
		
		def urem(lhs, rhs, name = '')
			URemInst.new(Bindings.build_u_rem(@ptr, lhs, rhs, name))
		end
		
		# Negation
		
		def neg(val, name = '')
			NegInst.new(Bindings.build_neg(@ptr, val, name))
		end
		
		def fneg(val, name = '')
			FNegInst.new(Bindings.build_f_neg(@ptr, val, name))
		end
		
		def nsw_neg(val, name = '')
			NSWNegInst.new(Bindings.build_nsw_neg(@ptr, val, name))
		end
		
		def nuw_neg(val, name = '')
			NUWNegInst.new(Bindings.build_nuw_neg(@ptr, val, name))
		end
		
		######################
		# Bitwise Operations #
		######################
		
		def shift(dir, lhs, rhs, mode = :arithmatic, name = '')
			case dir
			when :left	then shift_left(lhs, rhs, name)
			when :right	then shift_right(lhs, rhs, mode, name)
			end
		end
		
		def shift_left(lhs, rhs, name = '')
			LeftShiftInst.new(Bindings.build_shl(@ptr, lhs, rhs, name))
		end
		alias :shl :shift_left
		
		def shift_right(lhs, rhs, mode = :arithmatic, name = '')
			case mode
			when :arithmatic	then ashr(lhs, rhs, name)
			when :logical		then lshr(lhs, rhs, name)
			else raise 'The mode parameter must be either :arithmatic or :logical.'
			end 
		end
		
		def ashr(lhs, rhs, name = '')
			ARightShiftInst.new(Bindings.build_a_shr(lhs, rhs, name))
		end
		
		def lshr(lhs, rhs, name = '')
			LRightShiftInst.new(Bindings.build_l_shr(lhs, rhs, name))
		end
		
		def and(lhs, rhs, name = '')
			AndInst.new(Bindings.build_and(@ptr, lhs, rhs, name))
		end
		
		def or(lhs, rhs, name = '')
			OrInst.new(Bindings.build_or(@ptr, lhs, rhs, name))
		end
		
		def xor(lhs, rhs, name = '')
			XOrInst.new(Bindings.build_xor(@ptr, lhs, rhs, name))
		end
		
		def not(val, name = '')
			NotInst.new(Bindings.build_not(@ptr, val, name))
		end
		
		#####################
		# Memory Management #
		#####################
		
		def malloc(type, name = '')
			MallocInst.new(Bindings.build_malloc(@ptr, check_type(type), name))
		end
		
		def array_malloc(type, size, name = '')
			ArrayMallocInst.new(Bindings.build_array_malloc(@ptr, check_type(type), size, name))
		end
		
		def alloca(type, name = '')
			AllocaInst.new(Bindings.build_alloca(@ptr, check_type(type), name))
		end
		
		def array_alloca(type, size, name = '')
			ArrayAllocaInst.new(Bindings.build_array_alloca(@ptr, check_type(type), size, name))
		end
		
		def free(ptr)
			FreeInst.new(Bindings.build_free(@ptr, ptr))
		end
		
		def load(ptr, name = '')
			LoadInst.new(Bindings.build_load(@ptr, ptr, name))
		end
		
		def store(val, ptr)
			StoreInst.new(Bindings.build_store(@ptr, val, ptr))
		end
		
		def get_element_ptr(ptr, indices, name = '')
			check_array_type(indices, Value, 'indices')
			
			FFI::MemoryPointer.new(FFI.type_size(:pointer) * indices.length) do |indices_ptr|
				indices_ptr.write_array_of_pointer(indices)
				
				GEPInst.new(Bindings.build_gep(@ptr, ptr, indices_ptr, indices.length, name))
			end
		end
		alias :gep :get_element_ptr
		
		def get_element_ptr_in_bounds(ptr, indices, name = '')
			check_array_type(indices, Value, 'indices')
			
			FFI::MemoryPointer.new(FFI.type_size(:pointer) * indices.length) do |indices_ptr|
				indices_ptr.write_array_of_pointer(indices)
				
				InBoundsGEPInst.new(Bindings.build_in_bounds_gep(@ptr, ptr, indices_ptr, indices.length, name))
			end
		end
		alias :inbounds_gep :get_element_ptr_in_bounds
		
		def struct_get_element_ptr(ptr, index, name = '')
			StructGEPInst.new(Bindings.build_struct_gep(@ptr, ptr, index, name))
		end
		alias :struct_getp :struct_get_element_ptr
		
		def global_string(string, name = '')
			GlobalStringInst.new(Bindings.build_global_string(@ptr, string, name))
		end
		
		def gloabl_string_pointer(string, name = '')
			GlobalStringPtrInst(Bindings.build_global_string_ptr(@ptr, string, name))
		end
		
		###############################
		# Type and Value Manipluation #
		###############################
		
		def bitcast(val, type, name = '')
			BitCastInst.new(Bindings.build_bit_cast(@ptr, val, check_type(type), name))
		end
		
		def floating_point_cast(val, type, name = '')
			FPCastInst.new(Bindings.build_fp_cast(@ptr, val, check_type(type), name))
		end
		alias :fp_cast :floating_point_cast
		
		def floating_point_extend(val, type, name = '')
			FPExtendInst.new(Bindings.build_fp_ext(@ptr, val, check_type(type), name))
		end
		alias :fp_extend :floating_point_extend
		
		def floating_point_to_signed_int(val, type, name = '')
			FPToSIInst.new(Bindings.build_fp_to_si(@ptr, val, check_type(type), name))
		end
		alias :fp2si :floating_point_to_signed_int
		
		def floating_point_to_unsigned_int(val, type, name = '')
			FPToUIInst.new(Bindings.build_fp_to_ui(@ptr, val, check_type(type), name))
		end
		alias :fp2ui :floating_point_to_unsigned_int
		
		def floating_point_truncate(val, type, name = '')
			FPTruncInst.new(Bindings.build_fp_trunc(@ptr, val, check_type(type), name))
		end
		alias :fp_truncate :floating_point_truncate
		
		def int_to_ptr(val, type, name = '')
			IntToPtrInst.new(Bindings.build_int_to_ptr(@ptr, val, check_type(type), name))
		end
		alias :int2Ptr :int_to_ptr
		
		def int_cast(val, type, name = '')
			IntCastInst.new(Bindings.build_int_cast(@ptr, val, check_type(type), name))
		end
		alias :int_cast :integer_cast
		
		def ptr_cast(val, type, name = '')
			PtrCastInst.new(Bindings.build_pointer_cast(@ptr, val, check_type(type), name))
		end
		
		def ptr_to_int(val, type, name = '')
			PtrToIntInst.new(Bindings.build_ptr_to_int(@ptr, val, check_type(type), name))
		end
		alias :ptr2int :ptr_to_int
		
		def sign_extend(val, type, name = '')
			SignExtendInst.new(Bindings.build_s_ext(val, check_type(type), name))
		end
		alias :sext :sign_extend
		
		def sign_extend_or_bitcast(val, type, name = '')
			SignExtendOrBitCastInst.new(Bindings.build_s_ext_or_bit_cast(@ptr, val, check_type(type), name))
		end
		alias :sext_or_bitcast :sign_extend_or_bitcast
		
		def signed_int_to_floating_point(val, type, name = '')
			SIToFPInst.new(Bindings.build_si_to_fp(@ptr, val, check_type(type), name))
		end
		
		def truncate(val, type, name = '')
			TruncateInst.new(Bindings.build_trunc(@ptr, val, check_type(type), name))
		end
		
		def truncate_or_bitcast(val, type, name = '')
			TruncateOrBitCastInst.new(Bindings.build_trunc_or_bit_cast(@ptr, val, check_type(type), name))
		end
		
		def unsgined_int_to_floating_point(val, type, name = '')
			UIToFPInst.new(Bindings.build_ui_to_fp(@ptr, val, check_type(type), name))
		end
		alias :ui2fp
		
		def zero_extend(val, type, name = '')
			ZeroExtendInst.new(Bindings.build_z_ext(val, check_type(type), name))
		end
		alias :zext :zero_extend
		
		def zero_extend_or_bitcast(val, type, name = '')
			ZeroExtendOrBitCastInst.new(Bindings.build_z_ext_or_bit_cast(@ptr, val, check_type(type), name))
		end
		alias :zext_or_bitcast :zero_extend_or_bitcast
		
		###########################
		# Comparison Instructions #
		###########################
		
		def int_comparison(pred, lhs, rhs, name = '')
			IntCmpInst.new(Bindings.build_i_cmp(@ptr, pred, lhs, rhs, name))
		end
		alias :icmp :int_comparison
		
		def fp_comparison(pred, lhs, rhs, name = '')
			FPCmpInst.new(Bindings.build_f_cmp(@ptr, pred, lhs, rhs, name))
		end
		alias :fcmp :fp_comparison
		
		def ptr_diff(lhs, rhs, name = '')
			PtrDiffInst.new(Bindings.build_ptr_diff(lhs, rhs, name))
		end
		
		def is_not_null(val, name = '')
			IsNotNullInst.new(Builder.build_is_not_null(@ptr, val, name))
		end
		
		def is_null(val, name = '')
			IsNullInst.new(Bindings.build_is_null(@ptr, val, name))
		end
	end
end
