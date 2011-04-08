# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::Lexer class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/lexer'
require 'rltk/lexers/calc'
require 'rltk/lexers/ebnf'

#######################
# Classes and Modules #
#######################

class LexerTester < Test::Unit::TestCase
	def test_calc
		expected =
			[
				Token.new(:NUM, 1),
				
				Token.new(:PLS),
				Token.new(:SUB),
				Token.new(:MUL),
				Token.new(:DIV),
				
				Token.new(:LPAREN),
				Token.new(:RPAREN),
			]
		
		actual = RLTK::Lexers::Calc.lex('1 + - * / ( )')
		
		assert_equal(expected, actual)
	end
	
	def test_ebnf
	
	end
	
	def test_environment
	
	end
	
	def test_first_match
	
	end
	
	def test_flags
	
	end
	
	def test_longest_match
	
	end
	
	def test_state
	
	end
end
