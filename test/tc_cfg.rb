# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/04/06
# Description: This file contains unit tests for the RLTK::CFG class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/cfg'

#######################
# Classes and Modules #
#######################

class CFGTester < Minitest::Test
	def setup
		@grammar = RLTK::CFG.new

		@grammar.production(:s) do
			clause('A G D')
			clause('A a C')
			clause('B a D')
			clause('B G C')
		end

		@grammar.production(:a, 'b')
		@grammar.production(:b, 'G')
	end

	def test_callback
		grammar = RLTK::CFG.new

		call_count = 0
		grammar.callback do |type, which, p|
			refute_nil(p)
			assert_equal(type, :optional)

			case call_count
			when 0 then assert_equal(:empty, which)
			when 1 then assert_equal(:nonempty, which)
			end

			call_count += 1
		end

		grammar.production(:a, 'A?') { |a| a }
		assert_equal(2, call_count)

		call_count = 0
		grammar.callback do |type, which, p|
			refute_nil(p)

			case call_count
			when 0
				assert_equal(:elp, type)
				assert_equal(:empty, which)

			when 1
				assert_equal(:elp, type)
				assert_equal(:nonempty, which)

			when 2
				assert_equal(:nelp, type)
				assert_equal(:single, which)

			when 3
				assert_equal(:nelp, type)
				assert_equal(:multiple, which)
			end

			call_count += 1
		end

		grammar.production(:a, 'A*') { |a| a }
		assert_equal(4, call_count)

		call_count = 0
		grammar.callback do |type, which, p|
			refute_nil(p)
			assert_equal(type, :nelp)

			case call_count
			when 0 then assert_equal(:single, which)
			when 1 then assert_equal(:multiple, which)
			end

			call_count += 1
		end

		grammar.production(:a, 'A+') { |a| a }
		assert_equal(2, call_count)
	end

	def test_first_set
		@grammar.first_set(:s).each do |sym|
			assert_includes([:A, :B], sym)
		end

		assert_equal([:G], @grammar.first_set(:b))
		assert_equal([:G], @grammar.first_set(:a))
	end

	def test_follow_set
		assert_equal(@grammar.follow_set(:s), [:EOS])

		@grammar.follow_set(:a).each do |sym|
			assert([:C, :D].include?(sym))
		end

		@grammar.follow_set(:b).each do |sym|
			assert([:C, :D].include?(sym))
		end
	end

	def test_is_nonterminal
		assert( RLTK::CFG::is_nonterminal?(:lowercase))
		assert(!RLTK::CFG::is_nonterminal?(:UPERCASE))
	end

	def test_is_terminal
		assert(!RLTK::CFG::is_terminal?(:lowercase))
		assert( RLTK::CFG::is_terminal?(:UPERCASE))
	end

	def test_item
		i0 = RLTK::CFG::Item.new(0, 0, :a, [:b, :C, :D, :e])
		i1 = i0.copy

		assert_equal(i0, i1)
		assert(!i0.at_end?)
		assert_equal(:b, i0.next_symbol)

		i0.advance

		refute_equal(i0, i1)
		assert(!i0.at_end?)
		assert_equal(:C, i0.next_symbol)

		i0.advance
		assert(!i0.at_end?)
		assert_equal(:D, i0.next_symbol)

		i0.advance
		assert(!i0.at_end?)
		assert_equal(:e, i0.next_symbol)

		i0.advance
		assert(i0.at_end?)
		assert_nil(i0.next_symbol)
	end

	def test_production
		p0 = RLTK::CFG::Production.new(0, :a, [:b, :C, :D, :e])
		p1 = p0.copy

		assert_equal(p0, p1)
		assert_equal(:D, p0.last_terminal)
	end
end
