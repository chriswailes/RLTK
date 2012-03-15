# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the Support module.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg'
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG::Support
	extend RLTK::CG::Bindings::Support
	
	class << self
		def load_library(lib)
			LLVMLoadLibraryPermanently(lib) == 1 ? true : false
		end
	end
end
