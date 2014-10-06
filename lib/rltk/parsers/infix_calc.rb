# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/04
# Description:	This file contains a parser for a simple infix calculator.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/parser'

#######################
# Classes and Modules #
#######################

module RLTK

	# The RLTK::Parsers module contains the parsers that are included as part
	# of the RLKT project.
	module Parsers

		# A parser for a simple infix calculator.
		class InfixCalc < Parser

			left :PLS, :SUB
			right :MUL, :DIV

			production(:e) do
				clause('NUM') { |n| n }

				clause('LPAREN e RPAREN') { |_, e, _| e }

				clause('e PLS e') { |e0, _, e1| e0 + e1 }
				clause('e SUB e') { |e0, _, e1| e0 - e1 }
				clause('e MUL e') { |e0, _, e1| e0 * e1 }
				clause('e DIV e') { |e0, _, e1| e0 / e1 }
			end

			finalize
		end
	end
end
