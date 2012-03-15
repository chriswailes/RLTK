# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file adds some autoload features for the RLTK code
#			generation.

#######################
# Classes and Modules #
#######################

module RLTK
	module CG
		autoload :Bindings, 'rltk/cg/bindings'
		autoload :LLVM    , 'rltk/cg/llvm'
	end
end
