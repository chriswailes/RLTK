# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file provides a base Node class for ASTs.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/util/monkeys'

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	# A TypeMismatch is raised when an object being set as a child or value of
	# an ASTNode is of the wrong type.
	class TypeMismatch < StandardError
		
		# Instantiates a new TypeMismatch object.
		#
		# @param [Class] expected	Expected type.
		# @param [Klass] actual		Actual type of object.
		def initialize(expected, actual)
			@expected	= expected
			@actual	= actual
		end
		
		# @return [String] String representation of the error.
		def to_s
			"Type Mismatch: Expected #{@expected} but received #{@actual}."
		end
	end
	
	# This class is a good start for all your abstract syntax tree node needs.
	class ASTNode
		# @return [ASTNode] Reference to the parent node.
		attr_accessor :parent
		
		#################
		# Class Methods #
		#################
		
		class << self
			
			# Installs instance class varialbes into a class.
			#
			# @return [void]
			def install_icvars
				if self.superclass == ASTNode
					@child_names = Array.new
					@value_names = Array.new
				else
					@child_names = self.superclass.child_names.clone
					@value_names = self.superclass.value_names.clone
				end
			end
			protected :install_icvars
			
			# Called when the Lexer class is sub-classed, it installes
			# necessary instance class variables.
			#
			# @param [Class] klass The class is inheriting from this class.
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
			# @param [String, Symbol]	name Name of child node.
			# @param [Class]			type Type of child node.  Must be a subclass of ASTNode.
			#
			# @return [void]
			def child(name, type)
				if type.is_a?(Array) and type.length == 1
					t = type.first
				
				elsif type.is_a?(Class)
					t = type
					
				else
					raise 'Child and Value types must be a class name or an array with a single class name element.'
				end
				
				# Check to make sure that type is a subclass of
				# ASTNode.
				if not t.subclass_of?(ASTNode)
					raise "A child's type specification must be a subclass of ASTNode."
				end
				
				@child_names << name
				define_accessor(name, type, true)
			end
			
			# @return [Array<Symbol>] Array of the names of this node class's children.
			def child_names
				@child_names
			end
			
			# This method defines a type checking accessor named *name*
			# with type *type*.
			#
			# @param [String, Symbol]	name			Name of accessor.
			# @param [Class]			type			Class used for type checking.
			# @param [Boolean]			set_parent	Set the parent variable or not.
			#
			# @return [void]
			def define_accessor(name, type, set_parent = false)
				ivar_name = ('@' + name.to_s).to_sym
				
				define_method(name) do
					self.instance_variable_get(ivar_name)
				end
				
				if type.is_a?(Class)
					if set_parent
						define_method((name.to_s + '=').to_sym) do |value|
							if value.is_a?(type) or value == nil
								self.instance_variable_set(ivar_name, value)
							
								value.parent = self if value
							else
								raise TypeMismatch.new(type, value.class)
							end
						end
						
					else
						define_method((name.to_s + '=').to_sym) do |value|
							if value.is_a?(type) or value == nil
								self.instance_variable_set(ivar_name, value)
								
							else
								raise TypeMismatch.new(type, value.class)
							end
						end
					end
					
				else
					type = type.first
					
					if set_parent
						define_method((name.to_s + '=').to_sym) do |value|
							if value.inject(true) { |m, o| m and o.is_a?(type) }
								self.instance_variable_set(ivar_name, value)
							
								value.each { |c| c.parent = self }
							else
								raise TypeMismatch.new(type, value.class)
							end
						end
						
					else
						define_method((name.to_s + '=').to_sym) do |value|
							if value.inject(true) { |m, o| m and o.is_a?(type) }
								self.instance_variable_set(ivar_name, value)
								
							else
								raise TypeMismatch.new(type, value.class)
							end
						end
					end
				end
			end
			private :define_accessor
			
			# Defined a value for this AST class and its subclasses.
			# The name of the value will be used to define accessor
			# methods that include type checking.  The type of this
			# value must NOT be a subclass of the ASTNode class.
			#
			# @param [String, Symbol]	name Name of value.
			# @param [Class]			type Type of value.  Must NOT be a subclass of ASTNode.
			#
			# @return [void]
			def value(name, type)
				if type.is_a?(Array) and type.length == 1
					t = type.first
				
				elsif type.is_a?(Class)
					t = type
					
				else
					raise 'Child and Value types must be a class name or an array with a single class name element.'
				end
				
				# Check to make sure that type is NOT a subclass of
				# ASTNode.
				if t.subclass_of?(ASTNode)
					raise "A value's type specification must NOT be a subclass of ASTNode."
				end
				
				@value_names << name
				define_accessor(name, type)
			end
			
			# @return [Array<Symbol>] Array of the names of this node class's values.
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
		# @param [ASTNode] other The ASTNode to compare to.
		#
		# @return [Boolean]
		def ==(other)
			self.class == other.class and self.values == other.values and self.children == other.children
		end
		
		# @return [Object] Note with the name *key*.
		def [](key)
			@notes[key]
		end
		
		# Sets the note named *key* to *value*.
		def []=(key, value)
			@notes[key] = value
		end
		
		# @return [Array<ASTNode>] Array of this node's children.
		def children
			self.class.child_names.map { |name| self.send(name) }
		end
		
		# Assigns an array of AST nodes as the children of this node.
		#
		# @param [Array<ASTNode>] children Children to be assigned to this node.
		#
		# @return [void]
		def children=(children)
			if children.length != self.class.child_names.length
				raise 'Wrong number of children specified.'
			end
			
			self.class.child_names.each_with_index do |name, i|
				self.send((name.to_s + '=').to_sym, children[i])
			end
		end
		
		# Removes the note *key* from this node.  If the *recursive* argument
		# is true it will also remove the note from the node's children.
		#
		# @param [Object]	key		The key of the note to remove.
		# @param [Boolean]	recursive	Do a recursive removal or not.
		def delete_note(key, recursive = true)
			if recursive
				self.children.each do |child|
					next if not child
					
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
		# @param [nil, IO, String]	dest		Where the serialized version of the AST will end up.  If nil, this method will return the AST as a string.
		# @param [Fixnum]			limit	Recursion depth.  If -1 is specified there is no limit on the recursion depth.
		#
		# @return [void, String] String if *dest* is nil, void otherwise.
		def dump(dest = nil, limit = -1)
			case dest
			when nil		then Marshal.dump(self, limit)
			when String	then File.open(dest, 'w') { |f| Marshal.dump(self, f, limit) }
			when IO		then Marshal.dump(self, dest, limit)
			else	raise TypeError, "AST#dump expects nil, a String, or an IO object for the dest parameter."
			end
		end
		
		# An iterator over the node's children.  The AST may be traversed in
		# the following orders:
		#	* Pre-order (:pre)
		#	* Post-order (:post)
		#	* Level-order (:level)
		#
		# @return [void]
		def each(order = :pre, &block)
			case order
			when :pre
				yield self
				
				self.children.compact.each { |c| c.each(:pre, &block) }
				
			when :post
				self.children.compact.each { |c| c.each(:post, &block) }
				
				yield self
				
			when :level
				level_queue = [self]
				
				while node = level_queue.shift
					yield node
					
					level_queue += node.children.compact
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
		# @param [Array<Object>] objects The values and children of this node.
		def initialize(*objects)
			if self.class == RLTK::ASTNode
				raise 'Attempting to instantiate the RLTK::ASTNode class.'
			else
				@notes	= Hash.new()
				@parent	= nil
				
				# Pad out the objects array with nil values.
				max_args = self.class.value_names.length + self.class.child_names.length
				objects.fill(nil, objects.length...max_args)
				
				pivot = self.class.value_names.length
				
				self.values	= objects[0...pivot]
				self.children	= objects[pivot..-1]
			end
		end
		
		# Maps the children of the ASTNode from one value to another.
		#
		# @return [void]
		def map
			self.children = self.children.map { |c| yield c }
		end
		
		# @return [ASTNode] Root of the abstract syntax tree.
		def root
			if @parent then @parent.root else self end
		end
		
		# @return [Array<Object>] Array of this node's values.
		def values
			self.class.value_names.map { |name| self.send(name) }
		end
		
		# Assigns an array of objects as the values of this node.
		#
		# @param [Array<Object>] values The values to be assigned to this node.
		def values=(values)
			if values.length != self.class.value_names.length
				raise 'Wrong number of values specified.'
			end
			
			self.class.value_names.each_with_index do |name, i|
				self.send((name.to_s + '=').to_sym, values[i])
			end
		end
	end
end
