# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file holds bindings to LLVM.

#########
# Notes #
#########

# 1) initialize_all_target_m_cs -> initialize_all_target_mcs
# 2) initialize_obj_carc_opts   -> initialize_objc_arc_opts

############
# Requires #
############

# Gems
require 'ffi'
require 'filigree/boolean'

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# This module provides access to stored FFI::Pointer objects and allows a
	# class to be passed directly into FFI methods.  It also provides a
	# pointer comparison method.
	module BindingClass
		# @return [FFI::Pointer]
		attr_accessor :ptr
		alias :to_ptr :ptr

		# Compares one BindingClass object to another.
		#
		# @param [BindingClass] other Another BindingClass object to compare to.
		#
		# @return [Boolean]
		def ==(other)
			self.class == other.class and @ptr == other.ptr
		end
	end

	# This module contains FFI bindings to LLVM.
	module Bindings
		extend FFI::Library
		ffi_lib("LLVM-#{RLTK::LLVM_TARGET_VERSION}")

		# Exception that is thrown when the LLVM target version does not
		# match the version of LLVM present on the system.
		class LibraryMismatch < Exception; end

		# Require the generated bindings files while handling errors.
		require 'rltk/cg/generated_bindings'

		#############
		# Constants #
		#############

		# List of architectures supported by LLVM.
		ARCHS = [
			:Alpha,
			:ARM,
			:Blackfin,
			:CBackend,
			:CellSPU,
			:CppBackend,
			:MBlaze,
			:Mips,
			:MSP430,
			:PowerPC,
			:PTX,
			:Sparc,
			:SystemZ,
			:X86,
			:XCore
		]

		# List of assembly parsers.
		ASM_PARSERS = [
			:ARM,
			:MBLaze,
			:X86
		]

		# List of assembly printers.
		ASM_PRINTERS = [
			:Alpha,
			:ARM,
			:Blackfin,
			:CellSPU,
			:MBLaze,
			:Mips,
			:MSP430,
			:PowerPC,
			:PTX,
			:Sparc,
			:SystemZ,
			:X86,
			:XCore
		]

		###########
		# Methods #
		###########

		# Converts a CamelCase string into an underscored string.
		#
		# @param [#to_s] name CamelCase string.
		#
		# @return [Symbol] Underscored string.
		def self.get_bname(name)
			name.to_s.
				gsub(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2').
				gsub(/([a-z\d])([A-Z])/,'\1_\2').
				downcase.to_sym
		end

		# A wrapper class for FFI::Library.attach_function
		#
		# @param [Symbol]		func		Function name.
		# @param [Array<Object>] args		Argument types for FFI::Library.attach_function.
		# @param [Object]		returns	Return type for FFI::Library.attach_function.
		def self.add_binding(func, args, returns)
			attach_function(get_bname(func.to_s[4..-1]), func, args, returns)
		end

		####################
		# Missing Bindings #
		####################

		ARCHS.each do |arch|
			add_binding("LLVMInitialize#{arch}Target", [], :void)
			add_binding("LLVMInitialize#{arch}TargetInfo", [], :void)
			add_binding("LLVMInitialize#{arch}TargetMC", [], :void)
		end

		ASM_PARSERS.each do |asm|
			add_binding("LLVMInitialize#{asm}AsmParser", [], :void)
		end

		ASM_PRINTERS.each do |asm|
			add_binding("LLVMInitialize#{asm}AsmPrinter", [], :void)
		end
	end
end
