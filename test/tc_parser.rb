# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::Parser class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/lexer'
require 'rltk/parser'
require 'rltk/parsers/prefix_calc'
require 'rltk/parsers/infix_calc'
require 'rltk/parsers/postfix_calc'

#######################
# Classes and Modules #
#######################

class ABLexer < RLTK::Lexer
	rule(/A/) { [:A, 1] }
	rule(/B/) { [:B, 2] }
	
	rule(/\s/)
end

class APlusBParser < RLTK::Parser
	production(:a, 'A+ B') { |a, _| "Accepted with #{a.length} A(s)" }
	
	finalize
end

class AQuestionBParser < RLTK::Parser
	production(:a, 'A? B') { |a, _| "Accepted #{if a then 'with' else 'without' end} an A" }
	
	finalize
end

class AStarBParser < RLTK::Parser
	production(:a, 'A* B') { |a, _| "Accepted with #{a.length} A(s)" }
	
	finalize
end

class ParserTester < Test::Unit::TestCase
	def test_ambiguous_grammar
	
	end
	
	def test_array_args
	
	end
	
	def test_environment
	
	end
	
	def test_infix_calc
	
	end
	
	def test_input
	
	end
	
	def test_parse_stack
	
	end
	
	def test_postfix_calc
	
	end
	
	def test_prefix_calc
	
	end
	
	def test_state
		
	end
end
