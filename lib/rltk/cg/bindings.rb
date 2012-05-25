# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file holds bindings to LLVM.

############
# Requires #
############

# Gems
require 'rubygems'
require 'ffi'

# Ruby Language Toolkit
require 'rltk/util/monkeys'
require 'rltk/version'
require 'rltk/cg'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
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
	
		begin
			require 'rltk/cg/generated_extended_bindings'
		
			# Check to make sure that we have the same target version as the ECB.
			if target_version() != RLTK::LLVM_TARGET_VERSION
				raise LibraryMismatch,
					"Extended bindings expected LLVM version #{target_version()}, " +
					"RLTK expects LLVM version #{RLTK::LLVM_TARGET_VERSION}"
			end
		
			@ecb = true
		
		rescue FFI::NotFoundError
			@ecb = false
		end
	
		#############
		# Constants #
		#############
		
		# List of architectures supported by LLVM.
		ARCHS = [
			:ARM,
			:Alpha,
			:Blackfin,
			:CBackend,
			:CellSPU,
			:CppBackend,
			:MBlaze,
			:MSP430,
			:Mips,
			:PTX,
			:PowerPC,
			:Sparc,
			:SystemZ,
			:XCore,
			:X86
		]
	
		###########
		# Methods #
		###########
		
		# @return [Boolean] If the Extended C  Bindings for LLVM are present.
		def self.ecb?
			@ecb
		end
		
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
		
		add_binding(:LLVMDisposeMessage, [:pointer], :void)
	end
end
