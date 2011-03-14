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
				
				clause("e PLS NUM") {|e, _, n| e + n}
				
				clause("e SUB NUM") {|e, _, n| e - n}
				
				clause("e MUL NUM") {|e, _, n| e * n}
				
				clause("e DIV NUM") {|e, _, n| e / n}
			end
			
			finalize('calc.table')
		end
	end
end
