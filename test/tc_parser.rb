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
require 'rltk/lexers/calculator'
require 'rltk/parsers/prefix_calc'
require 'rltk/parsers/infix_calc'
require 'rltk/parsers/postfix_calc'

#######################
# Classes and Modules #
#######################

class ABLexer < RLTK::Lexer
	rule(/a/) { [:A, 1] }
	rule(/b/) { [:B, 2] }
	
	rule(/\s/)
end

class APlusBParser < RLTK::Parser
	production(:a, 'A+ B') { |a, _| a.length }
	
	finalize
end

class AQuestionBParser < RLTK::Parser
	production(:a, 'A? B') { |a, _| a }
	
	finalize
end

class AStarBParser < RLTK::Parser
	production(:a, 'A* B') { |a, _| a.length }
	
	finalize
end

class AmbiguousParser < RLTK::Parser
	production(:e) do
		clause('NUM') {|n| n}
		
		clause('e PLS e') { |e0, _, e1| e0 + e1 }
		
		clause('e SUB e') { |e0, _, e1| e0 - e1 }
		
		clause('e MUL e') { |e0, _, e1| e0 * e1 }
		
		clause('e DIV e') { |e0, _, e1| e0 / e1 }
	end
	
	finalize
end

class ArrayCalc < RLTK::Parser
	array_args
	
	production(:e) do
		clause('NUM') { |v| v[0] }
		
		clause('PLS e e') { |v| v[1] + v[2] }
		
		clause('SUB e e') { |v| v[1] - v[2] }
		
		clause('MUL e e') { |v| v[1] * v[2] }
		
		clause('DIV e e') { |v| v[1] / v[2] }
	end
	
	finalize
end

class DummyError1 < Exception; end
class DummyError2 < Exception; end

class ErrorCalc < RLTK::Parser
	production(:e) do
		clause('NUM') {|n| n}
		
		clause('e PLS e') { |e0, _, e1| e0 + e1 }
		
		clause('e SUB e') { |e0, _, e1| e0 - e1 }
		
		clause('e MUL e') { |e0, _, e1| e0 * e1 }
		
		clause('e DIV e') { |e0, _, e1| e0 / e1 }
		
		clause('e PLS ERROR') { |_, _, _| raise DummyError1 }
		clause('e SUB ERROR') { |_, _, _| raise DummyError2 }
	end
	
	finalize
end

class RotatingCalc < RLTK::Parser
	production(:e) do
		clause('NUM') {|n| n}
		
		clause('PLS e e') { |_, e0, e1| e0.send(get_op(:+), e1) }
		
		clause('SUB e e') { |_, e0, e1| e0.send(get_op(:-), e1) }
		
		clause('MUL e e') { |_, e0, e1| e0.send(get_op(:*), e1) }
		
		clause('DIV e e') { |_, e0, e1| e0.send(get_op(:/), e1) }
	end
	
	class Environment < Environment
		def initialize
			@map = { :+ => 0, :- => 1, :* => 2, :/ => 3 }
			@ops = [ :+, :-, :*, :/ ]
		end
		
		def get_op(orig_op)
			new_op = @ops[@map[orig_op]]
			
			@ops = @ops[1..-1] << @ops[0]
			
			new_op
		end
	end
	
	finalize
end

class ParserTester < Test::Unit::TestCase
	def test_ambiguous_grammar
		actual = AmbiguousParser.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3'), {:accept => :all})
		assert_equal([7, 9], actual.sort)
	end
	
	def test_array_args
		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
		assert_equal(3, actual)
		
		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 * 2 3'))
		assert_equal(7, actual)
		
		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3'))
		assert_equal(9, actual)
	end
	
	def test_ebnf_parsing
		################
		# APlusBParser #
		################
		
		assert_raise(RLTK::NotInLangauge) { APlusBParser.parse(ABLexer.lex('b')) }
		assert_equal(1, APlusBParser.parse(ABLexer.lex('ab')))
		assert_equal(2, APlusBParser.parse(ABLexer.lex('aab')))
		assert_equal(3, APlusBParser.parse(ABLexer.lex('aaab')))
		assert_equal(4, APlusBParser.parse(ABLexer.lex('aaaab')))
		
		####################
		# AQuestionBParser #
		####################
		
		assert_raise(RLTK::NotInLangauge) { AQuestionBParser.parse(ABLexer.lex('aab')) }
		assert_nil(AQuestionBParser.parse(ABLexer.lex('b')))
		assert_not_nil(AQuestionBParser.parse(ABLexer.lex('ab')))
		
		################
		# AStarBParser #
		################
		
		assert_equal(0, AStarBParser.parse(ABLexer.lex('b')))
		assert_equal(1, AStarBParser.parse(ABLexer.lex('ab')))
		assert_equal(2, AStarBParser.parse(ABLexer.lex('aab')))
		assert_equal(3, AStarBParser.parse(ABLexer.lex('aaab')))
		assert_equal(4, AStarBParser.parse(ABLexer.lex('aaaab')))
	end
	
	def test_environment
		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
		assert_equal(3, actual)
		
		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('/ 1 * 2 3'))
		assert_equal(7, actual)
		
		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('- + 1 2 3'))
		assert_equal(9, actual)
		
		parser = RotatingCalc.new
		
		actual = parser.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
		assert_equal(3, actual)
		
		actual = parser.parse(RLTK::Lexers::Calculator.lex('/ 1 2'))
		assert_equal(3, actual)
	end
	
	def test_error_productions
		assert_raise(DummyError1) { ErrorCalc.parse(RLTK::Lexers::Calculator.lex('1 + +')) }
		assert_raise(DummyError2) { ErrorCalc.parse(RLTK::Lexers::Calculator.lex('1 - +')) }
	end
	
	def test_infix_calc
		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2'))
		assert_equal(3, actual)
		
		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3'))
		assert_equal(7, actual)
		
		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('(1 + 2) * 3'))
		assert_equal(9, actual)
		
		assert_raise(RLTK::NotInLangauge) { RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 + 3 *')) }
	end
	
	def test_input
		assert_raise(RLTK::BadToken) { RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::EBNF.lex('A B C')) }
	end
	
	def test_postfix_calc
		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 +'))
		assert_equal(3, actual)
		
		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 3 * +'))
		assert_equal(7, actual)
		
		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 + 3 *'))
		assert_equal(9, actual)
		
		assert_raise(RLTK::NotInLangauge) { RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3')) }
	end
	
	def test_prefix_calc
		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
		assert_equal(3, actual)
		
		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 * 2 3'))
		assert_equal(7, actual)
		
		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3'))
		assert_equal(9, actual)
		
		assert_raise(RLTK::NotInLangauge) { RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3')) }
	end
end
