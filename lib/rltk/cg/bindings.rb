# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file holds bindings to LLVM.

############
# Requires #
############

# Ruby Gems
require 'rubygems'
require 'ffi'

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg'

#######################
# Classes and Modules #
#######################

module RLTK::CG::Bindings
	class LibraryMismatch < Exception; end
	
	# Build library names.
	LLVM_LIB     = "LLVM-#{RLTK::LLVM_TARGET_VERSION}"
	LLVM_ECB_LIB = "LLVM-ECB-#{RLTK::LLVM_TARGET_VERSION}"
	
	# Bindings for the CG::LLVM module.
	module LLVM
		# Extend this module with the FFI::Library module.
		extend FFI::Library
		
		def extended_bindings?
			@@ecb
		end
		
		def self.extended_bindings?
			@@ecb
		end
		
		begin
			# Load the LLVM Extended C Bindings library.
			ffi_lib(LLVM_ECB_LIB)
			
			@@ecb = true
		
		rescue LoadError
			@@ecb = false
		end
		
		if @@ecb
			# Attach the necessary functions.
			attach_function :extended_bindings_version, :LLVMECBVersion, [], :string
			attach_function :LLVMTargetVersion, [], :string
			
			# Declare the private functions.
			private :LLVMTargetVersion
			
			# Test to make sure we have matching target versions between
			# LLVM-ECB and RLTK.
			if self.LLVMTargetVersion() != RLTK::LLVM_TARGET_VERSION
				raise LibraryMismatch,
					"Extended bindings expected LLVM version #{self.LLVMTargetVersion()}, " +
					"RLTK expects LLVM version #{RLTK::LLVM_TARGET_VERSION}"
			end
		end
	end
	
	# Bindings for the CG::Support module.
	module Support
		# Extend this module with the FFI::Library module.
		extend FFI::Library
		
		if LLVM.extended_bindings?
			ffi_lib(LLVM_ECB_LIB)
		
			attach_function :LLVMLoadLibraryPermanently, [:string], :int
			private :LLVMLoadLibraryPermanently
		end
	end
	
	# Bindings for the CG::ExecutionEngine class.
	module ExecutionEngine
		# Extend this module with the FFI::Library module.
		extend FFI::Library
		
		# Load the LLVM library.
		ffi_lib(LLVM_LIB)
	end
end
