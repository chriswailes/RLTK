# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

# Standard Library

#######################
# Classes and Modules #
#######################

module RLTK
	class ParsingError < Exception; end
	
	class Parser
		def Parser.inherited(klass)
			klass.class_exec do
				
			end
		end
	end
end
