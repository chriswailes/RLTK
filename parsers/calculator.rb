# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/04
# Description:	This file contains a parser for a simple calculator.

############
# Requires #
############

# Ruby Language Toolkit
require File.join(File.dirname(__FILE__), '..', 'parser')

#######################
# Classes and Modules #
#######################

module RLTK
	module Parsers
		class Calc < Parser
			
			left :PLS, :SUB
			right :MUL, :DIV
			
			rule(:e) do
				clause("NUM") {|n| n}
				
				clause("e PLS e") {|e0, _, e1| e0 + e1}
				
				clause("e SUB e") {|e0, _, e1| e0 - e1}
				
				clause("e MUL e") {|e0, _, e1| e0 * e1}
				
				clause("e DIV e") {|e0, _, e1| e0 / e1}
			end
			
			finalize('calc.table')
		end
	end
end
