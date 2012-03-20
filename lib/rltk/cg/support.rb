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
	module Support
		def self.load_library(lib)
			not Bindings.load_library_permanently(lib).zero?
		end
	end
end
