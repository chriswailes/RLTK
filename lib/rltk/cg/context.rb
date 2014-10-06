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

	# Bindings for LLVM contexts.
	class Context
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.context_dispose(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

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

			# Define a finalizer to free the memory used by LLVM for this
			# context.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
		end
	end
end
