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

class ANode < RLTK::ASTNode
	child :left, ANode
	child :right, ANode
end

class BNode < ANode; end
class CNode < ANode; end

class DNode < RLTK::ASTNode; end

class ASTNodeTester < Test::Unit::TestCase
	def setup
		@leaf0 = CNode.new(nil, nil)
		@tree0 = ANode.new(BNode.new(@leaf0, nil), BNode.new(nil, nil))
		
		@tree1 = ANode.new(BNode.new(CNode.new(nil, nil), nil), BNode.new(nil, nil))
		@tree2 = ANode.new(BNode.new(nil, nil), BNode.new(CNode.new(nil, nil), nil))
	end
	
	def test_children
		node = ANode.new(nil, nil)
		
		assert_equal(node.children, [nil, nil])
		
		node.children = (expected_children = [BNode.new(nil, nil), CNode.new(nil, nil)])
		
		assert_equal(node.children, expected_children)
		
		node.map do |child|
			if child.is_a?(BNode)
				CNode.new(nil, nil)
			else
				BNode.new(nil, nil)
			end
		end
		
		assert_equal(node.children, expected_children.reverse)
	end
	
	def test_equal
		assert_equal(@tree0, @tree1)
		assert_not_equal(@tree0, @tree2)
	end
	
	def test_initialize
		assert_raise(Exception) { RLTK::ASTNode.new }
		assert_nothing_raised(Exception) { ANode.new(nil, nil) }
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
