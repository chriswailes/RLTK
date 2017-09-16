# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/04/06
# Description: This file contains unit tests for the RLTK::Lexer class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/token'
require 'rltk/lexer'
require 'rltk/lexers/calculator'
require 'rltk/lexers/ebnf'

#######################
# Classes and Modules #
#######################

class LexerTester < Minitest::Test
	class ABLongest < RLTK::Lexer
		rule(/a+/)   { :APLUS }
		rule(/b+/)   { :BPLUS }

		rule(/a+b+/) { :APLUSBPLUS }
	end

	class ABFirst < RLTK::Lexer
		match_first

		rule(/a+/)   { :APLUS }
		rule(/b+/)   { :BPLUS }

		rule(/a+b+/) { :APLUSBPLUS }
	end

	class ENVLexer < RLTK::Lexer
		rule(/a/)	{ [:A, next_value] }

		class Environment < Environment
			def initialize(*args)
				super(*args)
				@value = -1
			end

			def next_value
				@value += 1
			end
		end
	end

	class FlagLexer < RLTK::Lexer
		rule(/a/)  { set_flag(:a); :A }
		rule(/\s/)

		rule(/b/, :default, [:a])     { set_flag(:b); :B }
		rule(/c/, :default, [:a, :b]) { :C }
	end

	class StateLexer < RLTK::Lexer
		rule(/a/)  { :A }
		rule(/\s/)

		rule(/\(\*/) { push_state(:comment) }

		rule(/\(\*/, :comment) { push_state(:comment) }
		rule(/\*\)/, :comment) { pop_state }
		rule(/./,    :comment)
	end

	class MatchDataLexer < RLTK::Lexer
		rule(/a(b*)(c+)/) { [:FOO, match[1,2]] }
	end

	def test_calc
		expected = [
			RLTK::Token.new(:NUM, 1),

			RLTK::Token.new(:PLS),
			RLTK::Token.new(:SUB),
			RLTK::Token.new(:MUL),
			RLTK::Token.new(:DIV),

			RLTK::Token.new(:LPAREN),
			RLTK::Token.new(:RPAREN),
			RLTK::Token.new(:EOS)
		]

		actual = RLTK::Lexers::Calculator.lex('1 + - * / ( )')

		assert_equal(expected, actual)
	end

	def test_ebnf
		expected = [
			RLTK::Token.new(:NONTERM, :aaa),
			RLTK::Token.new(:TERM,    :BBB),

			RLTK::Token.new(:STAR),
			RLTK::Token.new(:PLUS),
			RLTK::Token.new(:QUESTION),
			RLTK::Token.new(:EOS)
		]

		actual = RLTK::Lexers::EBNF.lex('aaa BBB * + ?')
		assert_equal(expected, actual)
	end

	def test_environment
		expected = [
			RLTK::Token.new(:A, 0),
			RLTK::Token.new(:A, 1),
			RLTK::Token.new(:A, 2),
			RLTK::Token.new(:EOS)
		]

		actual = ENVLexer.lex('aaa')
		assert_equal(expected, actual)

		lexer = ENVLexer.new
		assert_equal(expected, lexer.lex('aaa'))

		expected = [
			RLTK::Token.new(:A, 3),
			RLTK::Token.new(:A, 4),
			RLTK::Token.new(:A, 5),
			RLTK::Token.new(:EOS)
		]
		assert_equal(expected, lexer.lex('aaa'))
	end

	def test_first_match
		expected = [
			RLTK::Token.new(:APLUS),
			RLTK::Token.new(:BPLUS),
			RLTK::Token.new(:EOS)
		]

		actual = ABFirst.lex('aaabbb')

		assert_equal(expected, actual)
	end

	def test_flags

		assert_raises(RLTK::LexingError) { FlagLexer.lex('b') }
		assert_raises(RLTK::LexingError) { FlagLexer.lex('ac') }

		expected = [
			RLTK::Token.new(:A),
			RLTK::Token.new(:B),
			RLTK::Token.new(:C),
			RLTK::Token.new(:EOS)
		]

		actual = FlagLexer.lex('abc')
		assert_equal(expected, actual)

		expected = [
			RLTK::Token.new(:A),
			RLTK::Token.new(:B),
			RLTK::Token.new(:C),
			RLTK::Token.new(:A),
			RLTK::Token.new(:B),
			RLTK::Token.new(:C),
			RLTK::Token.new(:EOS)
		]

		actual = FlagLexer.lex('abcabc')
		assert_equal(expected, actual)
	end

	def test_lex
		assert_raises(RLTK::LexingError) { ABFirst.lex('aaabbbCCC') }
		assert_raises(RLTK::LexingError) { ABLongest.lex('aaabbbCCC') }
	end

	def test_longest_match
		expected = [
			RLTK::Token.new(:APLUSBPLUS),
			RLTK::Token.new(:EOS)
		]

		actual = ABLongest.lex('aaabbb')
		assert_equal(expected, actual)
	end

	def test_match_data
		expected = [RLTK::Token.new(:FOO, ['', 'ccc']), RLTK::Token.new(:EOS)]
		actual   = MatchDataLexer.lex('accc')

		assert_equal(expected, actual)
	end

	def test_state
		expected = [
			RLTK::Token.new(:A),
			RLTK::Token.new(:A),
			RLTK::Token.new(:EOS)
		]

		actual = StateLexer.lex('a (* bbb *) a')
		assert_equal(expected, actual)

		actual = StateLexer.lex('a (* b (* ccc *) b *) a')
		assert_equal(expected, actual)
	end
end
