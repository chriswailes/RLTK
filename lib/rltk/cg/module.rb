# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Module class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Module
		def initialize(name)
			@ptr = Bindings.module_create_with_name
		end
	end
end
