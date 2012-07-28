# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::ASTNode class.

############
# Requires #
############

# Standard Library
require 'test/unit'
require 'pp'

# Ruby Language Toolkit
require 'rltk/ast'

#######################
# Classes and Modules #
#######################

class ASTNodeTester < Test::Unit::TestCase
	class ANode < RLTK::ASTNode
		child :left, ANode
		child :right, ANode
	end

	class BNode < ANode; end
	class CNode < ANode; end

	class DNode < RLTK::ASTNode; end
	
	class SNode < RLTK::ASTNode
		value :string, String
		
		child :left, SNode
		child :right, SNode
	end
	
	def setup
		@leaf0 = CNode.new
		@tree0 = ANode.new(BNode.new(@leaf0), BNode.new)
		
		@tree1 = ANode.new(BNode.new(CNode.new), BNode.new)
		@tree2 = ANode.new(BNode.new, BNode.new(CNode.new))
		
		@tree3 =	SNode.new('F',
					SNode.new('B',
						SNode.new('A'),
						SNode.new('D',
							SNode.new('C'),
							SNode.new('E')
						),
					),
					SNode.new('G',
						nil,
						SNode.new('I',
							SNode.new('H')
						)
					)
				)
	end
	
	def test_children
		node = ANode.new
		
		assert_equal(node.children, [nil, nil])
		
		node.children = (expected_children = [BNode.new, CNode.new])
		
		assert_equal(node.children, expected_children)
		
		node.map do |child|
			if child.is_a?(BNode)
				CNode.new
			else
				BNode.new
			end
		end
		
		assert_equal(node.children, expected_children.reverse)
	end
	
	def test_dump
		tree0_string = @tree0.dump
		
		reloaded_tree = Marshal.load(tree0_string)
		
		assert_equal(@tree0, reloaded_tree)
	end
	
	def test_each
		# Test pre-order
		nodes	= []
		expected	= ['F', 'B', 'A', 'D', 'C', 'E', 'G', 'I', 'H']
		@tree3.each(:pre) { |n| nodes << n.string }
		
		assert_equal(expected, nodes)
		
		# Test post-order
		nodes	= []
		expected	= ['A', 'C', 'E', 'D', 'B', 'H', 'I', 'G', 'F']
		@tree3.each(:post) { |n| nodes << n.string }
		
		assert_equal(expected, nodes)
		
		# Test level-order
		nodes	= []
		expected	= ['F', 'B', 'G', 'A', 'D', 'I', 'C', 'E', 'H']
		@tree3.each(:level) { |n| nodes << n.string }
		
		assert_equal(expected, nodes)
	end
	
	def test_equal
		assert_equal(@tree0, @tree1)
		assert_not_equal(@tree0, @tree2)
	end
	
	def test_initialize
		assert_raise(RuntimeError) { RLTK::ASTNode.new }
		assert_nothing_raised(RuntimeError) { ANode.new(nil, nil) }
	end
	
	def test_notes
		node = ANode.new(nil, nil)
		
		assert_nil(node[:a])
		assert_equal(node[:a] = :b, :b)
		assert_equal(node.note?(:a), true)
		assert_equal(node.note?(:b), false)
		assert_equal(node.delete_note(:a), :b)
		assert_nil(node[:a])
	end
	
	def test_root
		assert_same(@tree0, @tree0.root)
		assert_same(@tree0, @leaf0.root)
	end
end
