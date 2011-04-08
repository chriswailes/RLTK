# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::CFG class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/cfg'

#######################
# Classes and Modules #
#######################

class CFGTester < Test::Unit::TestCase
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
		
		first = true
		grammar.callback do |p, type, num|
			assert_not_nil(p)
			assert_equal(type, :'?')
			
			if first
				assert_equal(num, :first)
				first = false
			else
				assert_equal(num, :second)
			end
		end
		
		grammar.production(:a, 'A?') { |a| a }
		
		first = true
		grammar.callback do |p, type, num|
			assert_not_nil(p)
			assert_equal(type, :*)
			
			if first
				assert_equal(num, :first)
				first = false
			else
				assert_equal(num, :second)
			end
		end
		
		grammar.production(:a, 'A*') { |a| a }
		
		first = true
		grammar.callback do |p, type, num|
			assert_not_nil(p)
			assert_equal(type, :+)
			
			if first
				assert_equal(num, :first)
				first = false
			else
				assert_equal(num, :second)
			end
		end
		
		grammar.production(:a, 'A+') { |a| a }
	end
	
	def test_first_set
		@grammar.first_set(:s).each do |sym|
			assert([:A, :B].include?(sym))
		end
		
		assert_equal(@grammar.first_set(:b), [:G])
		assert_equal(@grammar.first_set(:a), [:G])
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
		assert_equal(RLTK::CFG::is_nonterminal?(:lowercase), true)
		assert_equal(RLTK::CFG::is_nonterminal?(:UPERCASE), false)
	end
	
	def test_is_terminal
		assert_equal(RLTK::CFG::is_terminal?(:lowercase), false)
		assert_equal(RLTK::CFG::is_terminal?(:UPERCASE), true)
	end
	
	def test_item
		i0 = RLTK::CFG::Item.new(0, 0, :a, [:b, :C, :D, :e])
		i1 = i0.copy
		
		assert_equal(i0, i1)
		assert_equal(i0.at_end?, false)
		assert_equal(i0.next_symbol, :b)
		
		i0.advance
		
		assert_not_equal(i0, i1)
		assert_equal(i0.at_end?, false)
		assert_equal(i0.next_symbol, :C)
		
		i0.advance
		assert_equal(i0.at_end?, false)
		assert_equal(i0.next_symbol, :D)
		
		i0.advance
		assert_equal(i0.at_end?, false)
		assert_equal(i0.next_symbol, :e)
		
		i0.advance
		assert_equal(i0.at_end?, true)
		assert_nil(i0.next_symbol)
	end
	
	def test_production
		p0 = RLTK::CFG::Production.new(0, :a, [:b, :C, :D, :e])
		p1 = p0.copy
		
		assert_equal(p0, p1)
		assert_equal(p0.last_terminal, :D)
	end
end
