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
end
