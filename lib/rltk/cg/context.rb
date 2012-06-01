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

module RLTK::CG # :nodoc:
	
	# Bindings for LLVM contexts.
	class Context
		include BindingClass
		
		#################
		# Class Methods #
		#################
		
		# @return [Context] A global context.
		def self.global
			self.new(Bindings.get_global_context())
		end
		
		####################
		# Instance Methods #
		####################
		
		# @param [FFI::Pointer, nil] ptr Pointer representing a context.  If nil, a new context is created.
		def initialize(ptr = nil)
			@ptr = ptr || Bindings.context_create()
		end
		
		# Frees the resources used by LLVM for this context.
		#
		# @return [void]
		def dispose
			if @ptr
				Bindings.context_dispose(@ptr)
				@ptr = nil
			end
		end
	end
end
