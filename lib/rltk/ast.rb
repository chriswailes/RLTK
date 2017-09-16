# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/01/19
# Description: This file provides a base Node class for ASTs.

############
# Requires #
############

# Gems
require 'filigree/abstract_class'
require 'filigree/class'
require 'filigree/match'
require 'filigree/types'
require 'filigree/visitor'

#######################
# Classes and Modules #
#######################

module RLTK
	using Filigree

	# This class is a good start for all your abstract syntax tree node needs.
	class ASTNode

		include Filigree::Visitable

		extend Filigree::AbstractClass
		extend Filigree::Destructurable

		# @return [ASTNode]  Reference to the parent node.
		attr_accessor :parent

		# @return [Hash]  The notes hash for this node.
		attr_reader :notes

		#################
		# Class Methods #
		#################

		class << self

			# @return [Array<Symbol>]  List of members (children and values) that have array types
			def array_members
				@array_members
			end

			# Check to make sure a name isn't re-defining a value or child.
			#
			# @raise [ArgumentError]  Raised if the name is already used for an existing value or child
			def check_odr(name)
				if @child_names.include? name
					raise ArgumentError,
					      "Class #{self} or one of its superclasses already defines a child named #{name}"
				end

				if @value_names.include?(name)
					raise ArgumentError,
					      "Class #{self} or one of its superclasses already defines a value named #{name}"
				end
			end

			# Installs instance class variables into a class.
			#
			# @return [void]
			def install_icvars
				if self.superclass == ASTNode
					@child_names   = Array.new
					@value_names   = Array.new
					@array_members = Array.new

					@member_order = :values
					@def_order    = Array.new
					@inc_children = Array.new
					@inc_values   = Array.new
				else
					@child_names   = self.superclass.child_names.clone
					@value_names   = self.superclass.value_names.clone
					@array_members = self.superclass.array_members.clone

					@member_order = (v = self.superclass.member_order).is_a?(Symbol) ? v : v.clone
					@def_order    = self.superclass.def_order.clone
					@inc_children = self.superclass.inc_children.clone
					@inc_values   = self.superclass.inc_values.clone
				end
			end
			protected :install_icvars

			# Called when the Lexer class is sub-classed, it installes
			# necessary instance class variables.
			#
			# @param [Class]  klass  The class is inheriting from this class.
			#
			# @return [void]
			def inherited(klass)
				klass.install_icvars
			end

			# Defined a child for this AST class and its subclasses.
			# The name of the child will be used to define accessor
			# methods that include type checking.  The type of this
			# child must be a subclass of the ASTNode class.
			#
			# @param [String, Symbol]  name  Name of child node
			# @param [Class]           type  Type of child node.  Must be a subclass of ASTNode.
			# @param [Boolean]         omit  Include the child in the constructor or not
			#
			# @return [void]
			def child(name, type, omit = false)
				check_odr(name)

				if type.is_a?(Array) and type.length == 1
					t = type.first

				elsif type.is_a?(Class)
					t = type

				else
					raise 'Child and Value types must be a class name or an array ' +
					      'with a single class name element.'
				end

				# Check to make sure that type is a subclass of ASTNode.
				if not t.subclass_of?(ASTNode)
					raise "A child's type specification must be a subclass of ASTNode."
				end

				@child_names   << name
				@array_members << name if type.is_a?(Array)

				if not omit
					@def_order    << name
					@inc_children << name
				end

				define_accessor(name, type, true)
			end

			# @return [Array<Symbol>]  Array of the names of this node class's children
			def child_names
				@child_names
			end

			# @return [Array<Symbol>]  Array of names of values/children in the order they were defined
			def def_order
				@def_order
			end

			# This method defines a type checking accessor named *name*
			# with type *type*.
			#
			# @param [String, Symbol]  name        Name of accessor
			# @param [Class]           type        Class used for type checking
			# @param [Boolean]         set_parent  Set the parent variable or not
			#
			# @return [void]
			def define_accessor(name, type, set_parent = false)
				ivar_name = ('@' + name.to_s).to_sym

				define_method(name) do
					self.instance_variable_defined?(ivar_name) ?
						self.instance_variable_get(ivar_name) : nil
				end

				if type.is_a?(Class)
					if set_parent
						define_method((name.to_s + '=').to_sym) do |value|
							self.instance_variable_set(ivar_name, check_type(value, type, nillable: true))
							value.parent = self if value
						end

					else
						define_method((name.to_s + '=').to_sym) do |value|
							self.instance_variable_set(ivar_name, check_type(value, type, nillable: true))
						end
					end

				else
					if set_parent
						define_method((name.to_s + '=').to_sym) do |value|
							self.instance_variable_set(ivar_name,
							                           check_array_type(value, type.first, nillable: true))

							value.each { |c| c.parent = self }
						end

					else
						define_method((name.to_s + '=').to_sym) do |value|
							self.instance_variable_set(ivar_name,
							                           check_array_type(value, type.first, nillable: true))
						end
					end
				end
			end
			private :define_accessor

			# Define a custom ordering for the class to use when building the
			# default constructor and destructurer.
			#
			# @param [Array<Symbol>]  members  List of member names
			#
			# @return [void]
			def custom_order(*members)
				@member_order = members
			end

			# @return [Array<Symbol>]  Array of the names of children that should be included in the constructor
			def inc_children
				@inc_children
			end

			# @return [Array<Symbol>]  Array of the names of values that should be included in the constructor
			def inc_values
				@inc_values
			end

			# A getter and setter for a class's initialization order.  If the
			# order value is `:values` the constructor will expect all of the
			# values and then the children.  If it is `:children` then the
			# constructor expects children and then values.  If it is `:def`
			# the constructor expects to values and children in the order that
			# they were defined.  If val is nil the current value will be
			# returned.
			#
			# The default ordering is `:values`, which matches the behavior of
			# previous versions of RLTK.
			#
			# @param [:values, :children, :def]  val  The new initialization order
			#
			# @return [:values, :children, :def]  The current initialization order
			def member_order(val = nil)
				if val
					@member_order = val
				else
					@member_order
				end
			end
			alias :order :member_order

			# Defined a value for this AST class and its subclasses.
			# The name of the value will be used to define accessor
			# methods that include type checking.
			#
			# @param [String, Symbol]  name  Name of value
			# @param [Class]           type  Type of value
			# @param [Boolean]         omit  Include the value in the constructor or not
			#
			# @return [void]
			def value(name, type, omit = false)
				check_odr(name)

				if not (type.is_a?(Class) or (type.is_a?(Array) and type.length == 1))
					raise 'Child and Value types must be a class name or an array ' +
					      'with a single class name element.'
				end

				@value_names   << name
				@array_members << name if type.is_a?(Array)

				if not omit
					@def_order  << name
					@inc_values << name
				end

				define_accessor(name, type)
			end

			# @return [Array<Symbol>]  Array of the names of this node class's values
			def value_names
				@value_names
			end
		end

		####################
		# Instance Methods #
		####################

		# Used for AST comparison, this function will return true if the two
		# nodes are of the same class and all of their values and children
		# are equal.
		#
		# @param [ASTNode]  other  The ASTNode to compare to
		#
		# @return [Boolean]
		def ==(other)
			self.class    == other.class    and
			self.values   == other.values   and
			self.children == other.children
		end

		# @return [Object]  Note with the name *key*
		def [](key)
			@notes[key]
		end

		# Sets the note named *key* to *value*.
		def []=(key, value)
			@notes[key] = value
		end

		# This method allows ASTNodes to be destructured for pattern matching.
		def destructure(arity)
			case self.class.member_order
			when :values   then (self.class.inc_values   + self.class.inc_children)
			when :children then (self.class.inc_children + self.class.inc_values)
			when :def      then  self.class.def_order
			when Array     then  self.class.member_order
			end.map { |m| self.send m }
		end

		# @param [Class]  as  The type that should be returned by the method.  Must be either Array or hash.
		#
		# @return [Array<ASTNode>, Hash{Symbol => ASTNode}] Array or Hash of this node's children.
		def children(as = Array)
			if as == Array
				self.class.child_names.map { |name| self.send(name) }

			elsif as == Hash
				self.class.child_names.inject(Hash.new) { |h, name| h[name] = self.send(name); h }

			else
				raise 'Children can only be returned as an Array or a Hash.'
			end
		end

		# Assigns an array or hash of AST nodes as the children of this node.
		# If a hash is provided as an argument the key is used as the name of
		# the child a object should be assigned to.
		#
		# @param [Array<ASTNode>, Hash{Symbol => ASTNode}]  children  Children to be assigned to this node.
		#
		# @return [void]
		def children=(children)
			case children
			when Array
				if children.length != self.class.child_names.length
					raise 'Wrong number of children specified.'
				end

				self.class.child_names.each_with_index do |name, i|
					self.send((name.to_s + '=').to_sym, children[i])
				end

			when Hash
				children.each do |name, val|
					if self.class.child_names.include?(name)
						self.send((name.to_s + '=').to_sym, val)
					else
						raise "ASTNode subclass #{self.class.name} does not have a child named #{name}."
					end
				end
			end
		end

		# Produce an exact copy of this tree.
		#
		# @return [ASTNode] A copy of the tree.
		def copy
			self.map { |c| c }
		end

		# Removes the note *key* from this node.  If the *recursive* argument
		# is true it will also remove the note from the node's children.
		#
		# @param [Object]   key        The key of the note to remove
		# @param [Boolean]  recursive  Do a recursive removal or not
		def delete_note(key, recursive = true)
			if recursive
				self.children.each do |child|
					next if child.nil?

					if child.is_a?(Array)
						child.each { |c| c.delete_note(key, true) }
					else
						child.delete_note(key, true)
					end
				end
			end

			@notes.delete(key)
		end

		# This method is a simple wrapper around Marshal.dump, and is used
		# to serialize an AST.  You can use Marshal.load to reconstruct a
		# serialized AST.
		#
		# @param [nil, IO, String]  dest   Where the serialized version of the AST will end up.  If nil,
		#                                  this method will return the AST as a string.
		# @param [Fixnum]           limit  Recursion depth.  If -1 is specified there is no limit on the
		#                                  recursion depth.
		#
		# @return [void, String]  String if *dest* is nil, void otherwise.
		def dump(dest = nil, limit = -1)
			case dest
			when nil    then Marshal.dump(self, limit)
			when String then File.open(dest, 'w') { |f| Marshal.dump(self, f, limit) }
			when IO     then Marshal.dump(self, dest, limit)
			else             raise TypeError, 'AST#dump expects nil, a String, or an IO object ' +
			                                  'for the dest parameter.'
			end
		end

		# An iterator over the node's children.  The AST may be traversed in
		# the following orders:
		#
		# * Pre-order (:pre)
		# * Post-order (:post)
		# * Level-order (:level)
		#
		# @param [:pre, :post, :level]  order  The order in which to iterate over the tree
		#
		# @return [void]
		def each(order = :pre, &block)
			case order
			when :pre
				yield self

				self.children.flatten.compact.each { |c| c.each(:pre, &block) }

			when :post
				self.children.flatten.compact.each { |c| c.each(:post, &block) }

				yield self

			when :level
				level_queue = [self]

				while node = level_queue.shift
					yield node

					level_queue += node.children.flatten.compact
				end
			end
		end

		# Tests to see if a note named *key* is present at this node.
		def has_note?(key)
			@notes.has_key?(key)
		end
		alias :'note?' :'has_note?'

		# Instantiates a new ASTNode object.  The arguments to this method are
		# split into two lists: the set of values for this node and a list of
		# its children.  If the node has 2 values and 3 children you would
		# pass the values in as the first two arguments (in the order they
		# were declared) and then the children as the remaining arguments (in
		# the order they were declared).
		#
		# If a node has 2 values and 2 children and is passed only a single
		# value the remaining values and children are assumed to be nil or
		# empty arrays, depending on the declared type of the value or
		# child.
		#
		# If a block is passed to initialize the block will be executed in
		# the conext of the new object.
		#
		# @param [Array<Object>]  objects  Values and children of this node
		def initialize(*objects, &block)
			@notes  = Hash.new()
			@parent = nil

			pairs =
			case self.class.member_order
			when :values   then (self.class.inc_values   + self.class.inc_children)
			when :children then (self.class.inc_children + self.class.inc_values)
			when :def      then  self.class.def_order
			when Array     then  self.class.member_order
			end.zip(objects).first(objects.length)

			pairs.each do |name, value|
				self.send("#{name}=", value)
			end

			self.class.array_members.each do |member|
				ivar_name = '@' + member.to_s
				self.instance_variable_set(ivar_name, []) if self.instance_variable_get(ivar_name).nil?
			end

			self.instance_exec(&block) if not block.nil?
		end

		# Create a new tree by using the provided Proc object to map the
		# nodes of this tree to new nodes.  This is always done in
		# post-order, meaning that all children of a node are visited before
		# the node itself.
		#
		# @note This does not modify the current tree.
		#
		# @return [Object]  Result of calling the given block on the root node
		def map(&block)
			new_values = self.values.map { |v| v.clone }

			new_children =
			self.children.map do |c0|
				case c0
				when Array    then c0.map { |c1| c1.map(&block) }
				when ASTNode  then c0.map(&block)
				when NilClass then nil
				end
			end

			new_node       = self.class.new(*new_values, *new_children)
			new_node.notes = self.notes

			block.call(new_node)
		end

		# Map the nodes in an AST to new nodes using the provided Proc
		# object.  This is always done in post-order, meaning that all
		# children of a node are visited before the node itself.
		#
		# @note The root node can not be replaced and as such the result of
		#       calling the provided block on the root node is used as the
		#       return value.
		#
		# @return [Object]  Result of calling the given block on the root node
		def map!(&block)
			self.children =
			self.children.map do |c0|
				case c0
				when Array    then c0.map { |c1| c1.map!(&block) }
				when ASTNode  then c0.map!(&block)
				when NilClass then nil
				end
			end

			block.call(self)
		end

		# Set the notes for this node from a given hash.
		#
		# @param [Hash]  new_notes  The new notes for this node.
		#
		# @return [void]
		def notes=(new_notes)
			@notes = new_notes.clone
		end

		# @return [ASTNode] Root of the abstract syntax tree.
		def root
			if @parent then @parent.root else self end
		end

		# @param [Class]  as  The type that should be returned by the method.  Must be either Array or hash.
		#
		# @return [Array<Object>, Hash{Symbol => Object}] Array or Hash of this node's values.
		def values(as = Array)
			if as == Array
				self.class.value_names.map { |name| self.send(name) }

			elsif as == Hash
				self.class.value_names.inject(Hash.new) { |h, name| h[name] = self.send(name); h }

			else
				raise 'Values can only be returned as an Array or a Hash.'
			end
		end

		# Assigns an array or hash of objects as the values of this node.  If
		# a hash is provided as an argument the key is used as the name of
		# the value an object should be assigned to.
		#
		# @param [Array<Object>, Hash{Symbol => Object}]  values  The values to be assigned to this node.
		def values=(values)
			case values
			when Array
				if values.length != self.class.value_names.length
					raise 'Wrong number of values specified.'
				end

				self.class.value_names.each_with_index do |name, i|
					self.send((name.to_s + '=').to_sym, values[i])
				end

			when Hash
				values.each do |name, val|
					if self.class.value_names.include?(name)
						self.send((name.to_s + '=').to_sym, val)
					else
						raise "ASTNode subclass #{self.class.name} does not have a value named #{name}."
					end
				end
			end
		end
	end
end
