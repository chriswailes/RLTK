# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the LLVM module.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
	# This module contains global operations on the LLVM compiler infrastructure.
	module LLVM
		# Initialize LLVM to generate code for a given architecture.  You may
		# also specify :all to initialize all targets or :native to
		# initialize the host target.
		#
		# @see Bindings::ARCHS
		#
		# @param [Symbol] arch Architecture to initialize LLVM for.
		#
		# @raise [ArgumentError] An error is raised if an unsupported architecture is specified.
		#
		# @return [void]
		def self.init(arch)
			if arch == :all
				Bindings.ecb_initialize_all_targets
			
			elsif arch == :native
				Bindings.ecb_initialize_native_target
			
			elsif Bindings::ARCHS.include?(arch) or Bindings::ARCHS.map { |sym| sym.to_s.downcase.to_sym }.include?(arch)
				arch = Bindings.get_bname(arch)
				
				Bindings.send("initialize_#{arch}_target".to_sym)
				Bindings.send("initialize_#{arch}_target_info".to_sym)
				Bindings.send("initialize_#{arch}_target_mc".to_sym)
			
			else
				raise ArgumentError, "Unsupported architecture specified: #{arch}."
			end
		end
		
		# Initialize a given ASM parser inside LLVM.  You may also specify
		# :all to initialize all ASM parsers.
		#
		# @see Bindings::ASM_PARSERS
		#
		# @param [Symbol] asm Assembly language type to initialize parser for.
		#
		# @raise [ArgumentError] An error is raised if an unsupported assembler parser is specified.
		#
		# @return [void]
		def self.init_asm_parser(asm)
			if arch == :all
				Bindings.initialize_all_asm_parsers
			
			elsif Bindings::ASM_PARSERS.include?(arch) or Bindings::ASM_PARSERS.map { |sym| sym.to_s.downcase.to_sym }.include?(arch)
				asm = Bindings.get_bname(asm)
				
				Bindings.send("initialize_#{asm}_asm_parser".to_sym)
			
			else
				raise ArgumentError, "Unsupported assembler type specified: #{arch}"
			end
		end
		
		# Initialize a given ASM printer inside LLVM.  You may also specify
		# :all to initialize all ASM printers or :native to initialize the
		# printer for the host machine's assembly language.
		#
		# @see Bindings::ASM_PRINTERS
		#
		# @param [Symbol] asm Assembly language type to initialize printer for.
		#
		# @raise [ArgumentError] An error is raised if an unsupported assembler printer is specified.
		#
		# @return [void]
		def self.init_asm_printer(asm)
			if arch == :all
				Bindings.initialize_all_asm_printers
			
			elsif arch == :native
				Bindings.initialize_native_asm_printer
			
			elsif Bindings::ASM_PRINTERS.include?(arch) or Bindings::ASM_PRINTERS.map { |sym| sym.to_s.downcase.to_sym }.include?(arch)
				asm = Bindings.get_bname(asm)
				
				Bindings.send("initialize_#{asm}_asm_printer".to_sym)
			
			else
				raise ArgumentError, "Unsupported assembler type specified: #{arch}"
			end
		end
		
		# @return [String] String representing the version of LLVM targeted by these bindings.
		def self.version
			RLTK::LLVM_TARGET_VERSION
		end
	end
end
