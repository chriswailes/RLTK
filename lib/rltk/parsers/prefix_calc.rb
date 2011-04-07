# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains a parser for a simple prefix calculator.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/parser'

#######################
# Classes and Modules #
#######################

module RLTK
	module Parsers
		class PrefixCalc < Parser
			
			production(:e) do
				clause("NUM") {|n| n}
				
				clause("LPAREN e RPAREN") { |_, e, _| e }
				
				clause("PLS e e") { |_, e0, e1| e0 + e1 }
				
				clause("SUB e e") { |_, e0, e1| e0 - e1 }
				
				clause("MUL e e") { |_, e0, e1| e0 * e1 }
				
				clause("DIV e e") { |_, e0, e1| e0 / e1 }
			end
			
			finalize
		end
	end
end
