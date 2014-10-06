# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/06/13
# Description:	This file defines the Triple class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# Class binding for the LLVM Triple class.
	class Triple
		include BindingClass

		#################
		# Class Methods #
		#################

		# @return [Triple] Object representing the host architecture, vendor, OS, and environment.
		def self.host
			@host ||= Triple.new(host_string)
		end

		# @return [String] String representation of the host architecture, vendor, OS, and environment.
		def self.host_string
			@host_string ||= Bindings.get_default_target_triple
		end

		####################
		# Instance Methods #
		####################

		# Create a new triple describing the host architecture, vendor, OS,
		# and (optionally) environment.
		#
		# @param [FFI::Pointer, String] overloaded
		def initialize(overloaded)
			@ptr, @str =
			case overloaded
			when FFI::Pointer then [overloaded, nil]
			when String       then [Bindings.triple_create(overloaded), overloaded]
			end
		end

		# @return [String] String representation of this triple.
		def to_s
			@str ||= Bindings.get_triple_string(@ptr)
		end
	end
end
