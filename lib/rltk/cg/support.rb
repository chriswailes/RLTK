# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the Support module.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# Support functionality for LLVM code generation.
	module Support
		# Load a shared library into memory and make its exported symbols
		# available to execution engines.
		#
		# @param [String]  lib  Path to the shared library to load
		def self.load_library(lib)
			Bindings.load_library_permanently(lib).to_bool
		end
	end
end
