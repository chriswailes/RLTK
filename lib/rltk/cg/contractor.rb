# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/09/21
# Description:	This file contains a combination of the Visitor and Builder
#			classes called a Contractor.

############
# Requires #
############

# Gems
require 'filigree/visitor'

# Ruby Language Toolkit
require 'rltk/cg/builder'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	class Contractor < Builder

		include Filigree::Visitor

		####################
		# Instance Methods #
		####################

		# Alias out the RLTK::Visitor.visit method.
		alias :wrapped_visit :visit

		# Visit an object in the context of this builder.  See the
		# Filigree::Visitor's visit method for more details about the basic
		# behaviour of this method.  The special options for this method are:
		#
		# @param [Object]      object  The object to visit.
		# @param [BasicBlock]  at      Where to position the contractor before visiting the object.
		# @param [Boolean]     rcb     If specified the method will also return the block where the contractor is currently positioned.
		#
		# @return [Object]
		def visit(object, at: nil, rcb: false)
			target at if at

			result = wrapped_visit(object)

			if rcb then [result, current_block] else result end
		end
	end
end
