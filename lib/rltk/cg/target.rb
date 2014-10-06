# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/06/13
# Description:	This file defines the Target class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/triple'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# Class binding for the LLVM Triple class.
	class Target
		include BindingClass

		#################
		# Class Methods #
		#################

		# @return [Target]  First target in the target list
		def self.first
			@first ||= self.new(Bindings.get_first_target)
		end

		# @return [Target] Target object for the host architecture.
		def self.host
			@host ||= self.new(Triple.host)
		end

		# @return [Target]  Next target in the target list
		def self.next_target(target)
			self.new(Bindings.get_next_target(target))
		end

		####################
		# Instance Methods #
		####################

		# Create an object representing a particular code generation target.
		# You can create a target either from a string or a Triple.
		#
		# @param [Triple, String] overloaded Object describing the target.
		def initialize(overloaded)
			@ptr, @triple =
			case overloaded
			when String
				[Bindings.get_target_from_name(overloaded), Triple.new(overloaded)]

			when RLTK::CG::Triple
				ptr    = FFI::MemoryPointer.new(:pointer)
				error  = FFI::MemoryPointer.new(:pointer)
				status = Bindings.get_target_from_triple(overloaded.to_s, ptr, error)

				if status.zero?
					[ptr, overloaded]

				else
					errorp  = error.read_pointer
					message = errorp.null? ? 'Unknown' : errorp.read_string

					error.autorelease = false

					Bindings.dispose_message(error)

					raise "Error creating target: #{message}"
				end

			when RLTK::CG::Bindings::Triple
				[overloaded, nil]
			end
		end

		# @return [Boolean]  Whether or not the target has an ASM backend
		def asm_backend?
			Bindings.target_has_asm_backend(@ptr).to_bool
		end

		# @return [Boolean]  Whether or not the target has a JIT
		def jit?
			Bindings.target_has_jit(@ptr).to_bool
		end

		# @return [Boolean]  Whether or not the target has a TargetMachine
		def target_machine?
			Bindings.target_has_target_machine(@ptr).to_bool
		end

		# @return [String]  Description of the target
		def describe
			Bindings.get_target_description(@ptr)
		end

		# @return [Triple]  Triple object for this target
		def triple
			@triple ||= Triple.new(Bindings.get_target_name(@ptr))
		end
	end

	# This class represents data about a specific architecture.  Currently it
	# is for internal use only and should not be instantiated by users.
	class TargetData
		include BindingClass

		# @param [FFI::Pointer] ptr
		def initialize(ptr)
			@ptr = ptr
		end

		# Gets the pointer size for this target machine and address space
		# combination.
		#
		# @param [Integer]  as  Address space
		#
		# @return [Integer]  Size of pointer
		def pointer_size(as)
			Bindings.pointer_size_for_as(@ptr, as)
		end
	end

	# This class represents a specific architecture that wil be targeted by
	# LLVM's compilation process.
	class TargetMachine
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_target_machine(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# @return [TargetMachine] TargetMachine representation of the host machine.
		def self.host
			@host ||= self.new(Target.host)
		end

		# Create a new object describing a target machine.
		#
		# @see Bindings._enum_reloc_model_
		# @see Bindings._enum_code_model_
		#
		# @param [Target]                                 target       Target description
		# @param [String]                                 mcpu         Specific CPU type to target
		# @param [Array<String>, String]                  features     Features present for this target machine
		# @param [Symbol from _enum_code_gen_opt_level_]  opt_level    Optimization level
		# @param [Symbol from _enum_reloc_mode_]          reloc_mode  Code relocation model
		# @param [Symbol from _enum_code_model_]          code_model   Code generation model
		def initialize(target, mcpu = '', features = '', opt_level = :none, reloc_mode = :default, code_model = :default)
			# Convert the features parameter if necessary.
			features = TargetMachine.build_feature_string(features) if features.is_a?(Array)

			@ptr = Bindings.create_target_machine(target, target.triple.to_s, mcpu, features, opt_level, reloc_mode, code_model)

			# Define a finalizer to free the memory used by LLVM for
			# this target machine.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
		end

		# @return [String]  Name of the target machine's CPU
		def cpu
			Bindings.get_target_machine_cpu(@ptr)
		end

		# @return [TargetData]
		def data
			TargetData.new(Bindings.get_target_machine_data(@pt))
		end

		# Emit assembly or object code for the given module to the file
		# specified.
		#
		# @param [Module]              mod        Module to emit code for
		# @param [String]              file_name  File to emit code to
		# @param [:assembly, :object]  emit_type  Type of code to emit
		#
		# @return [void]
		#
		# @raise LLVM error message if unable to emite code for module
		def emit_module(mod, file_name, emit_type)
			error  = FFI::MemoryPointer.new(:pointer)
			status = Bindings.target_machine_emit_to_file(@ptr, mod, file_name, emit_type, error)

			if not status.zero?
				errorp  = error.read_pointer
				message = errorp.null? ? 'Unknown' : errorp.read_string

				error.autorelease = false

				Bindings.dispose_message(error)

				raise "Error emiting code for module: #{message}"
			end
		end

		# @return [String]  Feature string for this target machine
		def feature_string
			Bindings.get_target_machine_feature_string(@ptr)
		end

		# @return [Target]
		def target
			Target.new(Bindings.get_target_machine_target(@ptr))
		end

		# @return [Triple]
		def triple
			Triple.new(Bindings.get_target_machine_triple(@ptr))
		end

		# Set verbose ASM property.
		#
		# @param [Boolean]  bool  Verbose ASM or not
		#
		# @return [void]
		def verbose_asm=(bool)
			@verbose_asm = bool

			Bindings.set_target_machine_asm_verbosity(@ptr, bool.to_i)
		end

		# @return [Boolean]  If this target machine should print verbose ASM
		def verbose_asm?
			@verbose_asm ||= false
		end
	end
end
