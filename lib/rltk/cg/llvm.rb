# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the LLVM module.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg'
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG::LLVM
	extend RLTK::CG::Bindings::LLVM
	
	class << self
		def version
			RLTK::LLVM_TARGET_VERSION
		end
	end
end
