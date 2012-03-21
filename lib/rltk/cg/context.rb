# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Context class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Context
		#################
		# Class Methods #
		#################
		
		def self.global
			self.new(Bindings.get_global_context())
		end
		
		####################
		# Instance Methods #
		####################
		
		def intialize(ptr = nil)
			@ptr = ptr || Bindings.context_create()
		end
		
		def dispose
			if not @ptr.nil?
				Bindings.context_dispose(@ptr)
				@ptr = nil
			end
		end
	end
end
