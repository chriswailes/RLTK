# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/09/20
# Description:	This file contains unit tests for the RLTK::Visitor class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/visitor'

#######################
# Classes and Modules #
#######################

class VisitorTester < Test::Unit::TestCase
	class GuardedVisitor < RLTK::Visitor
		on Integer, ->(i) { i < 10 } do
			true
		end
		
		on Integer, ->(i) { i >= 10 } do
			false
		end
	end

	class SimpleVisitor < RLTK::Visitor
		on Array do |a|
			a.map { |o| visit o }
		end
		
		on Integer do |i|
			i + 1
		end
	end
	
	class StatefulVisitor < RLTK::Visitor
		
		def initialize
			@accumulator = 0
		end
		
		on Array do |a|
			a.each { |o| visit o }
			
			@accumulator
		end
		
		on Integer do |i|
			@accumulator += i
		end
	end
	
	def test_guarded_visitor
		assert( GuardedVisitor.new.visit( 5))
		assert(!GuardedVisitor.new.visit(11))
	end
	
	def test_simple_visitor
		actual	= SimpleVisitor.new.visit([1, 2, 3, 4])
		expected	= [2, 3, 4, 5]
		
		assert_equal(expected, actual)
	end
	
	def test_stateful_visitor
		actual	= StatefulVisitor.new.visit([1, 2, 3, 4])
		expected	= 10
		
		assert_equal(expected, actual)
	end
end
