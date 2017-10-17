# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/04/06
# Description: This file contains unit tests for the RLTK::Parser class.

############
# Requires #
############

# Standard Library
require 'tmpdir'

# Gems
require 'minitest/autorun'

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

class ParserTester < Minitest::Test
#	class ABLexer < RLTK::Lexer
#		rule(/a/) { [:A, 1] }
#		rule(/b/) { [:B, 2] }

#		rule(/\s/)
#	end

	class AlphaLexer < RLTK::Lexer
		rule(/[A-Za-z]/) { |t| [t.upcase.to_sym, t] }

		rule(/,/) { :COMMA }

		rule(/\s/)
	end

#	class UnderscoreLexer < RLTK::Lexer
#		rule(/\w/) { |t| [:A_TOKEN, t] }
#	end

#	class APlusBParser < RLTK::Parser
#		production(:a, 'A+ B') { |a, _| a.length }

#		finalize
#	end

#	class AQuestionBParser < RLTK::Parser
#		production(:a, 'A? B') { |a, _| a }

#		finalize
#	end

#	class AStarBParser < RLTK::Parser
#		production(:a, 'A* B') { |a, _| a.length }

#		finalize
#	end

#	class AmbiguousParser < RLTK::Parser
#		production(:e) do
#			clause('NUM') {|n| n}

#			clause('e PLS e') { |e0, _, e1| e0 + e1 }
#			clause('e SUB e') { |e0, _, e1| e0 - e1 }
#			clause('e MUL e') { |e0, _, e1| e0 * e1 }
#			clause('e DIV e') { |e0, _, e1| e0 / e1 }
#		end

#		finalize
#	end

#	class ArrayCalc < RLTK::Parser
#		dat :array

#		production(:e) do
#			clause('NUM') { |v| v[0] }

#			clause('PLS e e') { |v| v[1] + v[2] }
#			clause('SUB e e') { |v| v[1] - v[2] }
#			clause('MUL e e') { |v| v[1] * v[2] }
#			clause('DIV e e') { |v| v[1] / v[2] }
#		end

#		finalize
#	end

#	# This grammar is purposefully ambiguous.  This should not be equivalent
#	# to the grammar produced with `e -> A B? B?`, due to greedy Kleene
#	# operators.
#	class AmbiguousParseStackParser < RLTK::Parser
#		production(:s, 'e*') { |e| e }

#		production(:e, 'A b_question b_question') { |a, b0, b1| [a, b0, b1] }

#		production(:b_question) do
#			clause('')	{ | | nil }
#			clause('B')	{ |b|   b }
#		end

#		finalize
#	end

#	class EBNFSelectorParser < RLTK::Parser
#		dat :array

#		production(:s) do
#			clause('.A .B* .A') { |a| a }
#			clause('.B C* .B')  { |a| a }
#		end

#		finalize
#	end

	puts "ELP0"

	class EmptyListParser0 < RLTK::Parser
		list('list', :A, :COMMA)

		finalize
	end

	puts "ELP1"

	class EmptyListParser1 < RLTK::Parser
		dat :array

		list('list', ['A', 'B', 'C D'], :COMMA)

		finalize explain: "elp1.pdesc"
	end

#	class GreedTestParser0 < RLTK::Parser
#		production(:e, 'A? A') { |a0, a1| [a0, a1] }

#		finalize
#	end

#	class GreedTestParser1 < RLTK::Parser
#		production(:e, 'A? A?') { |a0, a1| [a0, a1] }

#		finalize
#	end

#	class GreedTestParser2 < RLTK::Parser
#		production(:e, 'A* A') { |a0, a1| [a0, a1] }

#		finalize
#	end

#	class GreedTestParser3 < RLTK::Parser
#		production(:e, 'A+ A') { |a0, a1| [a0, a1] }

#		finalize
#	end

#	class NonEmptyListParser0 < RLTK::Parser
#		nonempty_list('list', :A, :COMMA)

#		finalize
#	end

#	class NonEmptyListParser1 < RLTK::Parser
#		nonempty_list('list', [:A, :B], :COMMA)

#		finalize explain: 'nelp1.tbl'
#	end

#	class NonEmptyListParser2 < RLTK::Parser
#		nonempty_list('list', ['A', 'B', 'C D'], :COMMA)

#		finalize
#	end

#	class NonEmptyListParser3 < RLTK::Parser
#		nonempty_list('list', 'A+', :COMMA)

#		finalize
#	end

#	class NonEmptyListParser4 < RLTK::Parser
#		nonempty_list('list', :A)

#		finalize
#	end

#	class NonEmptyListParser5 < RLTK::Parser
#		nonempty_list('list', :A, 'B C?')

#		finalize
#	end

#	class DummyError1 < StandardError; end
#	class DummyError2 < StandardError; end

#	class ErrorCalcParser < RLTK::Parser
#		left :ERROR
#		right :PLS, :SUB, :MUL, :DIV, :NUM

#		production(:e) do
#			clause('NUM') {|n| n}

#			clause('e PLS e') { |e0, _, e1| e0 + e1 }
#			clause('e SUB e') { |e0, _, e1| e0 - e1 }
#			clause('e MUL e') { |e0, _, e1| e0 * e1 }
#			clause('e DIV e') { |e0, _, e1| e0 / e1 }

#			clause('e PLS ERROR e') { |e0, _, ts, e1| error(ts); e0 + e1 }
#		end

#		finalize
#	end

#	class AssocCalcParser < RLTK::Parser
#		left :PLS, :DIV ; right :SUB, :MUL

#		production(:e) do
#			clause('NUM') {|n| n}

#			clause('e PLS e') { |e0, _, e1| e0 + e1 }
#			clause('e SUB e') { |e0, _, e1| e0 - e1 }
#			clause('e MUL e') { |e0, _, e1| e0 * e1 }
#			clause('e DIV e') { |e0, _, e1| e0 / e1 }
#		end

#		finalize
#	end

#	class ELLexer < RLTK::Lexer
#		rule(/\n/) { :NEWLINE }
#		rule(/;/)  { :SEMI    }

#		rule(/\s/)

#		rule(/[A-Za-z]+/) { |t| [:WORD, t] }
#	end

#	class ErrorLine < RLTK::Parser

#		production(:s, 'line*') { |l| l }

#		production(:line) do
#			clause('NEWLINE') { |_| nil }

#			clause('WORD+ SEMI NEWLINE') { |w, _, _| w }
#			clause('WORD+ ERROR')        { |w, e| error(pos(1).line_number); w }
#		end

#		finalize
#	end

#	class UnderscoreParser < RLTK::Parser
#		production(:s, 'A_TOKEN+') { |o| o }

#		finalize
#	end

#	class RotatingCalc < RLTK::Parser
#		production(:e) do
#			clause('NUM') {|n| n}

#			clause('PLS e e') { |_, e0, e1| e0.send(get_op(:+), e1) }
#			clause('SUB e e') { |_, e0, e1| e0.send(get_op(:-), e1) }
#			clause('MUL e e') { |_, e0, e1| e0.send(get_op(:*), e1) }
#			clause('DIV e e') { |_, e0, e1| e0.send(get_op(:/), e1) }
#		end

#		class Environment < Environment
#			def initialize
#				@map = { :+ => 0, :- => 1, :* => 2, :/ => 3 }
#				@ops = [ :+, :-, :*, :/ ]
#			end

#			def get_op(orig_op)
#				new_op = @ops[@map[orig_op]]

#				@ops = @ops[1..-1] << @ops[0]

#				new_op
#			end
#		end

#		finalize
#	end

#	class SelectionParser < RLTK::Parser
#		production(:s, 'A+ .B+') { |bs| bs.inject(&:+) }

#		finalize
#	end

#	class UselessParser < RLTK::Parser
#		production(:s, 'A+') { |a| a }
#	end

#	class TokenHookParser < RLTK::Parser
#		dat :array

#		production(:s) do
#			clause('A A A A') { |_| nil }
#			clause('B B B B') { |_| nil }
#		end

#		token_hook(:A) { @counter += 1 }
#		token_hook(:B) { @counter += 2 }

#		class Environment < Environment
#			attr_reader :counter

#			def initialize
#				@counter = 0
#			end
#		end

#		finalize
#	end

#	def test_ambiguous_grammar
#		actual = AmbiguousParser.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3'), {accept: :all})
#		assert_equal([7, 9], actual.sort)
#	end

	# This test is to ensure that objects placed on the output stack are
	# cloned when we split the parse stack.  This was posted as Issue #17 on
	# Github.
#	def test_ambiguous_parse_stack
#		assert_equal(1, AmbiguousParseStackParser.parse(ABLexer.lex('ab')).length)
#	end

#	def test_array_args
#		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
#		assert_equal(3, actual)

#		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 * 2 3'))
#		assert_equal(7, actual)

#		actual = ArrayCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3'))
#		assert_equal(9, actual)
#	end

#	def test_associativity
#		actual = AssocCalcParser.parse(RLTK::Lexers::Calculator.lex('5 - 3 - 2'))
#		assert_equal(4, actual)

#		actual = AssocCalcParser.parse(RLTK::Lexers::Calculator.lex('12 / 2 / 2'))
#		assert_equal(3, actual)
#	end

#	def test_construction_error
#		assert_raises(RLTK::ParserConstructionException) do
#			Class.new(RLTK::Parser) do
#				finalize
#			end
#		end
#	end

#	def test_ebnf_parsing
#		################
#		# APlusBParser #
#		################

#		assert_raises(RLTK::NotInLanguage) { APlusBParser.parse(ABLexer.lex('b')) }

#		assert_equal(1, APlusBParser.parse(ABLexer.lex('ab')))
#		assert_equal(2, APlusBParser.parse(ABLexer.lex('aab')))
#		assert_equal(3, APlusBParser.parse(ABLexer.lex('aaab')))
#		assert_equal(4, APlusBParser.parse(ABLexer.lex('aaaab')))

#		####################
#		# AQuestionBParser #
#		####################

#		assert_raises(RLTK::NotInLanguage) { AQuestionBParser.parse(ABLexer.lex('aab')) }
#		assert_nil(AQuestionBParser.parse(ABLexer.lex('b')))
#		refute_nil(AQuestionBParser.parse(ABLexer.lex('ab')))

#		################
#		# AStarBParser #
#		################

#		assert_equal(0, AStarBParser.parse(ABLexer.lex('b')))
#		assert_equal(1, AStarBParser.parse(ABLexer.lex('ab')))
#		assert_equal(2, AStarBParser.parse(ABLexer.lex('aab')))
#		assert_equal(3, AStarBParser.parse(ABLexer.lex('aaab')))
#		assert_equal(4, AStarBParser.parse(ABLexer.lex('aaaab')))
#	end

	def test_empty_list
		####################
		# EmptyListParser0 #
		####################

		expected = []
		actual   = EmptyListParser0.parse(AlphaLexer.lex(''))
		assert_equal(expected, actual)

		####################
		# EmptyListParser1 #
		####################

		expected = ['a', 'b', ['c', 'd']]
		actual   = EmptyListParser1.parse(AlphaLexer.lex('a, b, c d'), verbose: true)
		assert_equal(expected, actual)
	end

#	def test_greed

#		####################
#		# GreedTestParser0 #
#		####################

#		expected = [nil, 'a']
#		actual   = GreedTestParser0.parse(AlphaLexer.lex('a'))
#		assert_equal(expected, actual)

#		expected = ['a', 'a']
#		actual   = GreedTestParser0.parse(AlphaLexer.lex('a a'))
#		assert_equal(expected, actual)

#		####################
#		# GreedTestParser1 #
#		####################

#		expected = [nil, nil]
#		actual   = GreedTestParser1.parse(AlphaLexer.lex(''))
#		assert_equal(expected, actual)

#		# TODO: Figure out what to do with this.
##		expected = ['a', nil]
##		actual   = GreedTestParser1.parse(AlphaLexer.lex('a'))
##		assert_equal(expected, actual)

#		expected = ['a', 'a']
#		actual   = GreedTestParser1.parse(AlphaLexer.lex('a a'))
#		assert_equal(expected, actual)

#		####################
#		# GreedTestParser2 #
#		####################

#		expected = [[], 'a']
#		actual   = GreedTestParser2.parse(AlphaLexer.lex('a'))
#		assert_equal(expected, actual)

#		expected = [['a'], 'a']
#		actual   = GreedTestParser2.parse(AlphaLexer.lex('a a'))
#		assert_equal(expected, actual)

#		expected = [['a', 'a'], 'a']
#		actual   = GreedTestParser2.parse(AlphaLexer.lex('a a a'))
#		assert_equal(expected, actual)

#		####################
#		# GreedTestParser3 #
#		####################

#		expected = [['a'], 'a']
#		actual   = GreedTestParser3.parse(AlphaLexer.lex('a a'))
#		assert_equal(expected, actual)

#		expected = [['a', 'a'], 'a']
#		actual   = GreedTestParser3.parse(AlphaLexer.lex('a a a'))
#		assert_equal(expected, actual)
#	end

#	def test_ebnf_selector_interplay
#		expected = ['a', ['b', 'b', 'b'], 'a']
#		actual   = EBNFSelectorParser.parse(AlphaLexer.lex('abbba'))
#		assert_equal(expected, actual)

#		expected = ['a', [], 'a']
#		actual   = EBNFSelectorParser.parse(AlphaLexer.lex('aa'))
#		assert_equal(expected, actual)

#		expected = ['b', 'b']
#		actual   = EBNFSelectorParser.parse(AlphaLexer.lex('bb'))
#		assert_equal(expected, actual)

#		expected = ['b', 'b']
#		actual   = EBNFSelectorParser.parse(AlphaLexer.lex('bcccccb'))
#		assert_equal(expected, actual)
#	end

#	def test_environment
#		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
#		assert_equal(3, actual)

#		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('/ 1 * 2 3'))
#		assert_equal(7, actual)

#		actual = RotatingCalc.parse(RLTK::Lexers::Calculator.lex('- + 1 2 3'))
#		assert_equal(9, actual)

#		parser = RotatingCalc.new

#		actual = parser.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
#		assert_equal(3, actual)

#		actual = parser.parse(RLTK::Lexers::Calculator.lex('/ 1 2'))
#		assert_equal(3, actual)
#	end

#	def test_error_productions

#		# Test to see if error reporting is working correctly.

#		test_string  = "first line;\n"
#		test_string += "second line\n"
#		test_string += "third line;\n"
#		test_string += "fourth line\n"

#		assert_raises(RLTK::HandledError) { ErrorLine.parse(ELLexer.lex(test_string)) }

#		begin
#			ErrorLine.parse(ELLexer.lex(test_string))

#		rescue RLTK::HandledError => e
#			assert_equal([2,4], e.errors)
#		end

#		# Test to see if we can continue parsing after errors are encounterd.

#		begin
#			ErrorCalcParser.parse(RLTK::Lexers::Calculator.lex('1 + + 1'))

#		rescue RLTK::HandledError => e
#			assert_equal(1, e.errors.first.length)
#			assert_equal(2, e.result)
#		end

#		# Test to see if we pop tokens correctly after an error is
#		# encountered.

#		begin
#			ErrorCalcParser.parse(RLTK::Lexers::Calculator.lex('1 + + + + + + 1'))

#		rescue RLTK::HandledError => e
#			assert_equal(5, e.errors.first.length)
#			assert_equal(2, e.result)
#		end
#	end

#	def test_infix_calc
#		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2'))
#		assert_equal(3, actual)

#		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3'))
#		assert_equal(7, actual)

#		actual = RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('(1 + 2) * 3'))
#		assert_equal(9, actual)

#		assert_raises(RLTK::NotInLanguage) do
#			RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 + 3 *'))
#		end
#	end

#	def test_input
#		assert_raises(RLTK::BadToken) do
#			RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::EBNF.lex('A B C'))
#		end
#	end

#	def test_nonempty_list
#		#######################
#		# NonEmptyListParser0 #
#		#######################

#		expected = ['a']
#		actual   = NonEmptyListParser0.parse(AlphaLexer.lex('a'))
#		assert_equal(expected, actual)

#		expected = ['a', 'a']
#		actual   = NonEmptyListParser0.parse(AlphaLexer.lex('a, a'))
#		assert_equal(expected, actual)

#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser0.parse(AlphaLexer.lex(''))   }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser0.parse(AlphaLexer.lex(','))  }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser0.parse(AlphaLexer.lex('aa')) }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser0.parse(AlphaLexer.lex('a,')) }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser0.parse(AlphaLexer.lex(',a')) }

#		#######################
#		# NonEmptyListParser1 #
#		#######################

#		expected = ['a']
#		actual   = NonEmptyListParser1.parse(AlphaLexer.lex('a'))
#		assert_equal(expected, actual)

#		expected = ['b']
#		actual   = NonEmptyListParser1.parse(AlphaLexer.lex('b'))
#		assert_equal(expected, actual)

#		expected = ['a', 'b', 'a', 'b']
#		actual   = NonEmptyListParser1.parse(AlphaLexer.lex('a, b, a, b'))
#		assert_equal(expected, actual)

#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser1.parse(AlphaLexer.lex('a b')) }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser1.parse(AlphaLexer.lex('a, ')) }

#		#######################
#		# NonEmptyListParser2 #
#		#######################

#		expected = ['a']
#		actual   = NonEmptyListParser2.parse(AlphaLexer.lex('a'))
#		assert_equal(expected, actual)

#		expected = ['b']
#		actual   = NonEmptyListParser2.parse(AlphaLexer.lex('b'))
#		assert_equal(expected, actual)

#		expected = [['c', 'd']]
#		actual   = NonEmptyListParser2.parse(AlphaLexer.lex('c d'))
#		assert_equal(expected, actual)

#		expected = [['c', 'd'], ['c', 'd']]
#		actual   = NonEmptyListParser2.parse(AlphaLexer.lex('c d, c d'))
#		assert_equal(expected, actual)

#		expected = ['a', 'b', ['c', 'd']]
#		actual   = NonEmptyListParser2.parse(AlphaLexer.lex('a, b, c d'))
#		assert_equal(expected, actual)

#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser2.parse(AlphaLexer.lex('c')) }
#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser2.parse(AlphaLexer.lex('d')) }

#		#######################
#		# NonEmptyListParser3 #
#		#######################

#		expected = [['a'], ['a', 'a'], ['a', 'a', 'a']]
#		actual   = NonEmptyListParser3.parse(AlphaLexer.lex('a, aa, aaa'))
#		assert_equal(expected, actual)

#		#######################
#		# NonEmptyListParser4 #
#		#######################

#		expected = ['a', 'a', 'a']
#		actual   = NonEmptyListParser4.parse(AlphaLexer.lex('a a a'))
#		assert_equal(expected, actual)

#		#######################
#		# NonEmptyListParser5 #
#		#######################

#		expected = ['a', 'a', 'a']
#		actual   = NonEmptyListParser5.parse(AlphaLexer.lex('a b a b c a'))
#		assert_equal(expected, actual)

#		assert_raises(RLTK::NotInLanguage) { NonEmptyListParser5.parse(AlphaLexer.lex('a b b a')) }
#	end

#	def test_postfix_calc
#		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 +'))
#		assert_equal(3, actual)

#		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 3 * +'))
#		assert_equal(7, actual)

#		actual = RLTK::Parsers::PostfixCalc.parse(RLTK::Lexers::Calculator.lex('1 2 + 3 *'))
#		assert_equal(9, actual)

#		assert_raises(RLTK::NotInLanguage) do
#			RLTK::Parsers::InfixCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3'))
#		end
#	end

#	def test_prefix_calc
#		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 2'))
#		assert_equal(3, actual)

#		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('+ 1 * 2 3'))
#		assert_equal(7, actual)

#		actual = RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('* + 1 2 3'))
#		assert_equal(9, actual)

#		assert_raises(RLTK::NotInLanguage) do
#			RLTK::Parsers::PrefixCalc.parse(RLTK::Lexers::Calculator.lex('1 + 2 * 3'))
#		end
#	end

#	def test_selection_parser
#		actual   = SelectionParser.parse(ABLexer.lex('aaabbb'))
#		expected = 6

#		assert_equal(expected, actual)
#	end

#	def test_token_hooks
#		parser = TokenHookParser.new

#		parser.parse(AlphaLexer.lex('a a a a'))
#		assert_equal(4, parser.env.counter)

#		parser.parse(AlphaLexer.lex('b b b b'))
#		assert_equal(12, parser.env.counter)
#	end

#	def test_underscore_tokens
#		actual   = UnderscoreParser.parse(UnderscoreLexer.lex('abc')).join
#		expected = 'abc'

#		assert_equal(expected, actual)
#	end

#	def test_use
#		tmpfile = File.join(Dir.tmpdir, 'usetest')

#		FileUtils.rm(tmpfile) if File.exist?(tmpfile)

#		parser0 = Class.new(RLTK::Parser) do
#			production(:a, 'A+') { |a| a.length }

#			finalize use: tmpfile
#		end

#		result0 = parser0.parse(ABLexer.lex('a'))

#		assert(File.exist?(tmpfile), 'Serialized parser file not found.')

#		parser1 = Class.new(RLTK::Parser) do
#			production(:a, 'A+') { |a| a.length }

#			finalize use: tmpfile
#		end

#		result1 = parser1.parse(ABLexer.lex('a'))

#		assert_equal(result0, result1)

#		File.unlink(tmpfile)
#	end

#	def test_uesless_parser_exception
#		assert_raises(RLTK::UselessParserException) { UselessParser.new }
#	end
end
