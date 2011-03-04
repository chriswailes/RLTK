# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/04
# Description:	This file contains a lexer for a simple calculator.

############
# Requires #
############

# Ruby Language Toolkit
require File.join(File.dirname(__FILE__), '..', 'lexer')

#######################
# Classes and Modules #
#######################

module RLTK
	module Lexers
		class Calc < Lexer
			
			#################
			# Default State #
			#################
			
			rule(/\+/)	{ :PLS }
			rule(/-/)		{ :SUB }
			rule(/\*/)	{ :MUL }
			rule(/\//)	{ :DIV }
			
			rule(/[0-9]+/)	{ |t| [:NUM, t.to_i] }
			
			rule(/\s/)
		end
	end
end
