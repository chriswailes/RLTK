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
	class GuardedVisitor
		include RLTK::Visitor

		on Integer, :guard => proc { |i| i < 10 } do
			true
		end

		on Integer do
			false
		end
	end

#	class MultiClassVisitor < RLTK::Visitor
#		on [Numeric, String] do
#			:numANDstr
#		end
#
#		on Array do
#			:array
#		end
#
#		on Integer do
#			:int
#		end
#	end

	class NumericVisitor
		include RLTK::Visitor

		on Numeric do |n|
			"Numeric: #{n}"
		end
	end

	class SubclassVisitor < NumericVisitor

		on Integer do |i|
			"Integer: #{i}"
		end
	end

	class SimpleVisitor
		include RLTK::Visitor

		on Array do |a|
			a.map { |o| visit o }
		end

		on Integer do |i|
			i + 1
		end
	end

	class StatefulVisitor
		include RLTK::Visitor

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

	class WrappingVisitor
		include RLTK::Visitor

		def foo
			1
		end

		def wrapper_fun(o)
			1 + yield(o, 1)
		end

		on Integer, :wrapper => :wrapper_fun do |i, other|
			i + foo + other
		end
	end

	def test_guarded_visitor
		assert( GuardedVisitor.new.visit( 5))
		assert(!GuardedVisitor.new.visit(11))
	end

	def test_inheritance
		v = SubclassVisitor.new

		assert_equal("Numeric: 3.1415296", v.visit(3.1415296))
		assert_equal("Integer: 42",        v.visit(42))
	end

#	def test_multiclass
#		v = MultiClassVisitor.new
#
#		assert_equal(:integer, v.visit(1))
#		assert_equal(:array,   v.visit([1,2,3]))
#
#		assert_equal(:numANDstr, v.visit(42.0))
#		assert_equal(:numANDstr, v.visit('42'))
#	end

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

	def test_wrapping
		actual	= WrappingVisitor.new.visit(39)
		expected	= 42

		assert_equal(expected, actual)
	end
end
