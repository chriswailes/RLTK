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

module RLTK::CG
	module BindingClass
		attr_accessor :ptr
		alias :to_ptr :ptr
	
		def ==(other)
			self.class == other.class and @ptr == other.ptr
		end
	end
	
	module Bindings
		extend FFI::Library
		ffi_lib("LLVM-#{RLTK::LLVM_TARGET_VERSION}")
	
		class LibraryMismatch < Exception; end
	
		# Require the generated bindings files while handeling errors.
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
	
		def self.ecb?
			@ecb
		end
	
		def self.get_bname(name)
			name.to_s.
				gsub(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2').
				gsub(/([a-z\d])([A-Z])/,'\1_\2').
				downcase.to_sym
		end
	
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
