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

module RLTK::CG

	# This module contains global operations on the LLVM compiler infrastructure.
	module LLVM

		# Enable LLVM's built-in stack trace code. This intercepts the OS's
		# crash signals and prints which component of LLVM you were in at the
		# time if the crash.
		#
		# @return [void]
		def self.enable_pretty_stack_trace
			Bindings.enable_pretty_stack_trace
		end

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
				Bindings.initialize_all_targets

			elsif arch == :native
				Bindings.initialize_native_target

			elsif Bindings::ARCHS.include?(arch) or Bindings::ARCHS.map { |sym| sym.to_s.downcase.to_sym }.include?(arch)
				arch = Bindings.get_bname(arch)

				Bindings.send("initialize_#{arch}_target".to_sym)
				Bindings.send("initialize_#{arch}_target_info".to_sym)
				Bindings.send("initialize_#{arch}_target_mc".to_sym)

			else
				raise ArgumentError, "Unsupported architecture specified: #{arch}."
			end
		end

		# Initialize access to all available target MC that LLVM is
		# configured to support.
		#
		# @return [void]
		def self.initialize_all_target_mcs
			Bindings.initialize_all_target_mcs
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
			if asm == :all
				Bindings.initialize_all_asm_parsers

			elsif Bindings::ASM_PARSERS.include?(asm) or Bindings::ASM_PARSERS.map { |sym| sym.to_s.downcase.to_sym }.include?(asm)
				asm = Bindings.get_bname(asm)

				Bindings.send("initialize_#{asm}_asm_parser".to_sym)

			else
				raise ArgumentError, "Unsupported assembler type specified: #{asm}"
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
			if asm == :all
				Bindings.initialize_all_asm_printers

			elsif asm == :native
				Bindings.initialize_native_asm_printer

			elsif Bindings::ASM_PRINTERS.include?(asm) or Bindings::ASM_PRINTERS.map { |sym| sym.to_s.downcase.to_sym }.include?(asm)
				asm = Bindings.get_bname(asm)

				Bindings.send("initialize_#{asm}_asm_printer".to_sym)

			else
				raise ArgumentError, "Unsupported assembler type specified: #{asm}"
			end
		end

		def self.multithreaded?
			Bindings.is_multithreaded.to_bool
		end

		# Deallocate and destroy all ManagedStatic variables.
		#
		# @return [void]
		def self.shutdown
			Bindings.shutdown
		end

		# Initialize LLVM's multithreaded infrestructure.
		#
		# @return [void]
		def self.start_multithreaded
			Bindings.start_multithreaded
		end

		# Shutdown and cleanup LLVM's multithreaded infrastructure.
		def self.stop_multithreaded
			Bindings.stop_multithreaded
		end

		# @return [String] String representing the version of LLVM targeted by these bindings.
		def self.version
			RLTK::LLVM_TARGET_VERSION
		end
	end
end
