# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains unit tests for the RLTK::ASTNode class.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/ast'

#######################
# Classes and Modules #
#######################

class ANode < RLTK::ASTNode
	def children
		@children
	end
	
	def inspect
		"#{self.class.name}(#{@children.inspect})"
	end
	
	def set_children(children)
		@children = children
	end
	
	def to_src(indent = 0)
		src  = "#{"\t" * indent}#{self.class.name}(\n"
		
		@children.each do |child|
			src += child.to_src(indent + 1)
		end
		
		src += "#{"\t" * indent})\n"
	end
end

class BNode < ANode; end
class CNode < ANode; end

class DNode < RLTK::ASTNode; end

class ASTNodeTester < Test::Unit::TestCase
	def setup
		@leaf0 = CNode.new
		@tree0 = ANode.new([BNode.new([@leaf0]), BNode.new])
		
		@tree1 = ANode.new([BNode.new([CNode.new]), BNode.new])
		@tree2 = ANode.new([BNode.new, BNode.new([CNode.new])])
	end
	
	def test_children
		node = ANode.new
		
		assert_equal(node.children, [])
		
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
	
	def test_equal
		assert_equal(@tree0, @tree1)
		assert_not_equal(@tree0, @tree2)
	end
	
	def test_initialize
		assert_raise(Exception) { RLTK::ASTNode.new }
		assert_nothing_raised(Exception) { ANode.new }
	end
	
	def test_inspect
		assert_raise(RLTK::NotImplementedError) { DNode.new.inspect }
		assert_nothing_raised(RLTK::NotImplementedError) { ANode.new.inspect }
	end
	
	def test_notes
		node = ANode.new
		
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
	
	def test_to_src
		assert_raise(RLTK::NotImplementedError) { DNode.new.to_src }
		assert_nothing_raised(RLTK::NotImplementedError) { ANode.new.to_src }
	end
end
