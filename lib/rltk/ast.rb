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
		
		# Instantiates a new TypeMismatch object.  The first argument is the
		# expected type and the second argument is the actual type of the
		# object.
		def initialize(expected, actual)
			@expected	= expected
			@actual	= actual
		end
		
		# Converts the exception to a string.
		def to_s
			"Type Mismatch: Expected #{@expected} but received #{@actual}."
		end
	end
	
	# This class is a good start for all your abstract syntax tree node needs.
	class ASTNode
		# A reference to the parent node.
		attr_accessor :parent
		
		#################
		# Class Methods #
		#################
		
		class << self
			
			# Installes instance class varialbes into a class.
			def install_icvars
				if self.superclass == ASTNode
					@child_names = Array.new
					@value_names = Array.new
				else
					@child_names = self.superclass.child_names.clone
					@value_names = self.superclass.value_names.clone
				end
			end
			
			# Called when the Lexer class is sub-classed, it installes
			# necessary instance class variables.
			def inherited(klass)
				klass.install_icvars
			end
			
			# Defined a child for this AST class and its subclasses.
			# The name of the child will be used to define accessor
			# methods that include type checking.  The type of this
			# child must be a subclass of the ASTNode class.
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
				self.define_accessor(name, type, true)
			end
			
			# Returns an array of the names of this node class's children.
			def child_names
				@child_names
			end
			
			# This method defines a type checking accessor named _name_
			# with type _type_.
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
			
			# Defined a value for this AST class and its subclasses.
			# The name of the value will be used to define accessor
			# methods that include type checking.  The type of this
			# value must NOT be a subclass of the ASTNode class.
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
				self.define_accessor(name, type)
			end
			
			# Returns an array of the names of this node's values.
			def value_names
				@value_names
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		# Used for AST comparison, this function will return true if the two
		# nodes are of the same class and all of their values and children are
		# equal.
		def ==(other)
			self.class == other.class and self.values == other.values and self.children == other.children
		end
		
		# Returns the note with name _key_.
		def [](key)
			@notes[key]
		end
		
		# Sets the note named _key_ to _value_.
		def []=(key, value)
			@notes[key] = value
		end
		
		# Returns an array of this node's children.
		def children
			self.class.child_names.map { |name| self.send(name) }
		end
		
		# Assigns an array of AST nodes as the children of this node.
		def children=(children)
			if children.length != self.class.child_names.length
				raise 'Wrong number of children specified.'
			end
			
			self.class.child_names.each_with_index do |name, i|
				self.send((name.to_s + '=').to_sym, children[i])
			end
		end
		
		# Removes the note _key_ from this node.  If the _recursive_ argument
		# is true it will also remove the note from the node's children.
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
		
		# An iterator over the node's children.
		def each
			self.children.each { |c| yield c }
		end
		
		# Tests to see if a note named _key_ is present at this node.
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
		def initialize(*objects)
			if self.class == RLTK::ASTNode
				raise 'Attempting to instantiate the RLTK::ASTNode class.'
			else
				@notes	= Hash.new()
				@parent	= nil
				
				pivot = self.class.value_names.length
				
				self.values	= objects[0...pivot]
				self.children	= objects[pivot..-1]
			end
		end
		
		# Maps the children of the ASTNode from one value to another.
		def map
			self.children = self.children.map { |c| yield c }
		end
		
		# Find the root of an AST.
		def root
			if @parent then @parent.root else self end
		end
		
		# Returns an array of this node's values.
		def values
			self.class.value_names.map { |name| self.send(name) }
		end
		
		# Assigns an array of objects as the values of this node.
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
