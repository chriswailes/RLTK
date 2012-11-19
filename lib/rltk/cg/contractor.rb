# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/09/21
# Description:	This file contains a combination of the Visitor and Builder
#			classes called a Contractor.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/visitor'
require 'rltk/cg/builder'

#######################
# Classes and Modules #
#######################

module RLTK::CG # :nodoc:
	
	class Contractor
		
		include Visitor
		include Builder
		
		#################
		# Class Methods #
		#################
		
		class << self
			# A callback method that installs the necessary data structures
			# in sbuclasses.  This re-bases the inheritance heirarcy to the
			# Contractor class instead of the Visitor class.
			#
			# @return [void]
			def inherited(klass)
				klass.install_icvars(if self == RLTK::CG::Contractor then [] else @actions.clone end)
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		# Alias out the RLTK::Visitor.visit method.
		alias :wrapped_visit :visit
		
		def visit(object, opts = {})
			target opts[:at] if opts[:at]
			
			result = wrapped_visit(object)
			
			if opts[:rcb] then [result, current_block] else result end
		end
	end
end
