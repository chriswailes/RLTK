# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/06/13
# Description:	This file defines the Target class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:

	# Class binding for the LLVM Triple class.
	class Target
		include BindingClass
		
		attr_reader :triple
		
		# Create an object representing a particular code generation target.
		# You can create a target either from a string or a Triple.
		#
		# @param [Triple, String] overloaded Object describing the target.
		def initialize(overloaded)
			@ptr, @triple = 
			case overloaded
			when String	then [Bindings.get_target_from_string(overloaded), Triple.new(overloaded)]
			when Triple	then [Bindings.get_target_from_triple(overloaded), overloaded]
			end
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
	end
	
	# This class represents a specific architecture that wil be targeted by
	# LLVM's compilation process.
	class TargetMachine
		# Convert an array of strings representing features of a target
		# machine into a single string.
		#
		# @param [Array<String>] features Strings representing features of a target machine.
		#
		# @return [String] A single string representing all of the given features.
		def self.build_feature_string(features)
			strings_ptr = FFI::MemoryPointer.new(:pointer, features.length)
			strings_ptr.write_array_of_pointer(features.map { |str| FFI::MemoryPointer.from_string(str) })
			
			Bindings.build_features_string(strings_ptr, features.length)
		end
		
		# Create a new object describing a target machine.
		#
		# @see Bindings._enum_reloc_model_
		# @see Bindings._enum_code_model_
		#
		# @param [Target]				target		Target description.
		# @param [String]				mcpu			Specific CPU type to target.
		# @param [Array<String>, String]	features		Features present for this target machine.
		# @param [Symbol]				reloc_model	Code relocation model.
		# @param [Symbol]				code_model	Code generation model.
		def initialize(target, mcpu, features, reloc_model = :default, code_model = :default)
			# Just to make things easier on developers.
			reloc_model = :default_rmodel if reloc_model == :default
			code_model  = :default_cmodel if code_model  == :default
			
			# Convert the features parameter if necessary.
			features = TargetMachine.build_feature_string(features) if features.is_a?(Array)
			
			@ptr = Bindings.create_target_machine(target, target.triple.to_s, mcpu, features, reloc_model, code_model)
		end
	end
end
