# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/03/04
# Description: This file contains a lexer for a simple calculator.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/lexer'

#######################
# Classes and Modules #
#######################

module RLTK

	# The RLTK::Lexers module contains the lexers that are included as part of
	# the RLKT project.
	module Lexers

		# The Calculator lexer is a simple lexer for use with several of the
		# provided parsers.
		class Calculator < Lexer

			#################
			# Default State #
			#################

			rule(/\+/) { :PLS }
			rule(/-/)  { :SUB }
			rule(/\*/) { :MUL }
			rule(/\//) { :DIV }

			rule(/\(/) { :LPAREN }
			rule(/\)/) { :RPAREN }

			rule(/[0-9]+/) { |t| [:NUM, t.to_i] }

			rule(/\s/)
		end
	end
end
