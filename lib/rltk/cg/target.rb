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
		
		# Create an object representing a particular code generation target.
		# You can create a target either from a string or a Triple.
		#
		# @param [Triple, String] overloaded Object describing the target.
		def initialize(overloaded)
			@ptr = 
			case overloaded
			when String	then Bindings.get_target_from_string(overloaded)
			when Triple	then Bindings.get_target_from_triple(overloaded)
			end
		end
	end
end
