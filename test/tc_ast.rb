# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/04/06
# Description: This file contains unit tests for the RLTK::ASTNode class.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/ast'

#######################
# Classes and Modules #
#######################

class ASTNodeTester < Minitest::Test
	class ANode < RLTK::ASTNode
		child :left, ANode
		child :right, ANode
	end

	class BNode < ANode; end
	class CNode < ANode; end

	class DNode < RLTK::ASTNode; end

	class ENode < RLTK::ASTNode
		value :str, String
	end

	class FNode < ENode
		child :c, [ENode]
	end

	class SNode < RLTK::ASTNode
		value :string, String

		child :left, SNode
		child :right, SNode
	end

	class VNode < RLTK::ASTNode
		value :a, Integer
		value :b, Integer
	end

	class ONode < RLTK::ASTNode
		value :a, Integer
		value :b, Integer, true
		value :c, Integer
	end

	class ValuesFirstNode < RLTK::ASTNode
		child :b, ValuesFirstNode
		value :a, Integer
	end

	class ChildrenFirstNode < RLTK::ASTNode
		order :children

		value :b, Integer
		child :a, ChildrenFirstNode
	end

	class DefOrderNode < RLTK::ASTNode
		order :def

		value :a, Integer
		child :b, DefOrderNode
		value :c, Float
	end

	class CustomOrderNode < RLTK::ASTNode
		custom_order :a, :b, :c, :d

		child :b, CustomOrderNode
		child :d, CustomOrderNode

		value :a, Integer
		value :c, String
	end

	def setup
		@leaf0 = CNode.new
		@tree0 = ANode.new(BNode.new(@leaf0), BNode.new)

		@tree1 = ANode.new(BNode.new(CNode.new), BNode.new)
		@tree2 = ANode.new(BNode.new, BNode.new(CNode.new))
		@tree3 = ANode.new(CNode.new(BNode.new), CNode.new)

		@tree4 =
			SNode.new('F',
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

		@tree5 =
			FNode.new('one',
				[FNode.new('two',
					[ENode.new('three')]),
				 ENode.new('four')])

		@tree6 =
			FNode.new('one',
				[FNode.new('two',
					[ENode.new('three')]),
				 ENode.new('four')])

		@tree7 =
			FNode.new('one!',
				[FNode.new('two!',
					[ENode.new('three!')]),
				 ENode.new('four!')])

		@bc_proc = Proc.new do |n|
			case n
			when BNode then	CNode.new(n.left, n.right)
			when CNode then	BNode.new(n.left, n.right)
			else            n
			end
		end
	end

	def test_children
		node = ANode.new
		assert_equal(node.children, [nil, nil])

		node.children = (expected_children = [BNode.new, CNode.new])
		assert_equal(node.children, expected_children)

		node.children = (expected_children = {left: CNode.new, right: BNode.new})
		assert_equal(node.children(Hash), expected_children)
	end

	def test_copy
		new_tree = @tree5.copy

		assert_equal(@tree5, new_tree)
	end

	def test_dump
		tree0_string = @tree0.dump

		reloaded_tree = Marshal.load(tree0_string)

		assert_equal(@tree0, reloaded_tree)
	end

	def test_each
		# Test pre-order
		nodes    = []
		expected = ['F', 'B', 'A', 'D', 'C', 'E', 'G', 'I', 'H']
		@tree4.each(:pre) { |n| nodes << n.string }

		assert_equal(expected, nodes)

		# Test post-order
		nodes    = []
		expected = ['A', 'C', 'E', 'D', 'B', 'H', 'I', 'G', 'F']
		@tree4.each(:post) { |n| nodes << n.string }

		assert_equal(expected, nodes)

		# Test level-order
		nodes    = []
		expected = ['F', 'B', 'G', 'A', 'D', 'I', 'C', 'E', 'H']
		@tree4.each(:level) { |n| nodes << n.string }

		assert_equal(expected, nodes)

		# Test iteration with array children.

		res	= ''
		@tree5.each(:pre) { |node| res += ' ' + node.str }
		assert_equal(res, ' one two three four')

		res	= ''
		@tree5.each(:post) { |node| res += ' ' + node.str }
		assert_equal(res, ' three two four one')

		res	= ''
		@tree5.each(:level) { |node| res += ' ' + node.str }
		assert_equal(res, ' one two four three')
	end

	def test_equal
		assert_equal(@tree0, @tree1)
		refute_equal(@tree0, @tree2)
	end

	def test_initialize
		assert_raises(AbstractClassError) { RLTK::ASTNode.new }

		node = ENode.new { self.str = 'hello world' }
		assert_equal('hello world', node.str)
	end

	def test_map
		mapped_tree = @tree1.map(&@bc_proc)

		assert_equal(@tree0, @tree1)
		assert_equal(@tree3, mapped_tree)

		mapped_tree = @tree5.map do |c|
			c.tap { c.str += '!' }
		end

		assert_equal(@tree6, @tree5)
		assert_equal(@tree7, mapped_tree)
	end

	def test_map!
		tree1_clone = @tree1.clone
		tree1_clone.map!(&@bc_proc)

		refute_equal(@tree1, tree1_clone)
		assert_equal(@tree3, tree1_clone)

		replace_node = BNode.new
		replace_node = replace_node.map!(&@bc_proc)

		assert_equal(CNode.new, replace_node)

		@tree5.map! do |c|
			c.tap { c.str += '!' }
		end

		refute_equal(@tree6, @tree5)
		assert_equal(@tree7, @tree5)
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

	def test_omit
		onode = ONode.new(1, 3)

		assert_equal(1, onode.a)
		assert_nil(onode.b)
		assert_equal(3, onode.c)
	end

	def test_one_definition_rule
		asserter = self

		Class.new(ANode) do
			asserter.assert_raises(ArgumentError) { child :left, ANode }
		end

		Class.new(ENode) do
			asserter.assert_raises(ArgumentError) { value :str, String }
		end
	end

	def test_ordering
		vfn = ValuesFirstNode.new(42, ValuesFirstNode.new)

		a, b = vfn.destructure(2)

		assert_equal(42, a)
		assert_instance_of(ValuesFirstNode, b)

		cfn = ChildrenFirstNode.new(ChildrenFirstNode.new, 42)

		a, b = cfn.destructure(2)

		assert_instance_of(ChildrenFirstNode, a)
		assert_equal(42, b)

		dfn = DefOrderNode.new(4, DefOrderNode.new, 2.0)

		a, b, c = dfn.destructure(3)

		assert_equal(4, a)
		assert_instance_of(DefOrderNode, b)
		assert_equal(2.0, c)

		con = CustomOrderNode.new(42, CustomOrderNode.new, 'foo')

		a, b, c, d = con.destructure(4)

		assert_equal(42, a)
		assert_instance_of(CustomOrderNode, b)
		assert_equal('foo', c)
		assert_nil(d)
	end

	def test_root
		assert_same(@tree0, @tree0.root)
		assert_same(@tree0, @leaf0.root)
	end

	def test_value
		node = VNode.new
		assert_equal(node.values, [nil, nil])

		node.values = (expected_values = [42, 1984])
		assert_equal(node.values, expected_values)

		node.values = (expected_values = {:a => 1984, :b => 42})
		assert_equal(node.values(Hash), expected_values)
	end
end
