# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/20
# Description:	This file contains a lexer for Extended Backus–Naur Form.

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
		class EBNFLexer < Lexer
			
			#################
			# Default State #
			#################
			
			rule(/\*/)	{ :*   }
			rule(/\+/)	{ :+   }
			rule(/\?/)	{ :'?' }
			
			rule(/[a-z]+/)	{ |t| [:NONTERM, t.to_sym] }
			rule(/[A-Z]+/)	{ |t| [:TERM,    t.to_sym] }
			
			rule(/\s/)
		end
	end
end
