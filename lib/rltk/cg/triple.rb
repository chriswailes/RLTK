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

module RLTK::CG # :nodoc:

	# Class binding for the LLVM Triple class.
	class Triple
		include BindingClass
		
		#################
		# Class Methods #
		#################
		
		# @return [Triple] Object representing the host architecture, vendor, OS, and environment.
		def self.host
			@host ||= self.new(Bindings.get_host_triple)
		end
		
		# @return [String] String representation of the host architecture, vendor, OS, and environment.
		def self.host_string
			@host_string ||= Bindings.get_host_triple_string
		end
		
		####################
		# Instance Methods #
		####################
		
		# Create a new triple describing the host architecture, vendor, OS,
		# and (optionally) environment.
		#
		# @param [FFI::Pointer, String] overloaded
		def initialize(overloaded)
			@ptr = 
			case overloaded
			when FFI::Pointer	then overloaded
			when String		then Bindings.triple_create(overloaded)
			end
		end
		
		# @return [String] String representation of this triple.
		def to_s
			Bindings.get_triple_string(@ptr)
		end
	end
end
