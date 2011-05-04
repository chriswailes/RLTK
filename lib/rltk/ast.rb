# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file provides a base Node class for ASTs.

module RLTK # :nodoc:
	
	# A simple error class used to indicate that a function has not been
	# overwritten as it should be by inheriting classes.
	class NotImplementedError < Exception
		
		# Takes the offending object and the name of the offending method as
		# its first and second arguments, respectively.
		def initialize(obj, method)
			@class	= obj.class
			@method	= method
		end
		
		# Converts the exception to a string.
		def to_s
			"Function '#{@method}' not implemented for #{@class}."
		end
	end
	
	# This class is a good start for all your abstract syntax tree node needs.
	class ASTNode
		# A reference to the parent node.
		attr_accessor :parent
		
		# Used for AST comparison, this function will return true if the two
		# nodes are of the same class and all of their children are equal.  It
		# may be necessary to overwrite this method in subclasses to do
		# proper comparisons.
		def ==(other)
			self.class == other.class and self.children == other.children
		end
		
		# Returns the note with name _key_.
		def [](key)
			@notes[key]
		end
		
		# Sets the note named _key_ to _value_.
		def []=(key, value)
			@notes[key] = value
		end
		
		# Virtual Method.  Any subclasses of ASTNode should overwrite this
		# method with one that returns all of a nodes children as an array.
		def children
			raise(NotImplementedError.new(self, 'children'))
		end
		
		# Assigns an array of AST nodes as the children of this node.  This is
		# a wrapper around the ASTNode.set_children function, and takes care
		# of setting the childrens' new parent.
		def children=(children)
			self.set_children(children)
			
			children.each { |c| c.parent = self }
		end
		
		# Removes the note _key_ from this node.  If the _recursive_ argument
		# is true it will also remove the note from the node's children.
		def delete_note(key, recursive = true)
			self.children.each { |c| c.delete_note(key, recursive) } if recursive
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
		
		# Instantiates a new ASTNode object with _children_ set as the node's
		# children.
		def initialize(children = [])
			if self.class == RLTK::ASTNode
				raise Exception, 'Attempting to instantiate the RLTK::ASTNode class.'
			else
				@notes	= Hash.new()
				@parent	= nil
				
				self.children = children
			end
		end
		
		# Virtual Method.  Any subclasses of ASTNode should overwrite this
		# method with one that returns a string representation of the
		# structure of the AST.
		def inspect
			raise(NotImplementedError.new(self, 'inspect'))
		end
		
		# Maps the children of the ASTNode from one value to another.
		def map
			self.children = self.children.map { |c| yield c }
		end
		
		# Find the root of an AST.
		def root
			if @parent then @parent.root else self end
		end
		
		# Virtual Method.  Any subclass of ASTNode should overwrite this
		# method with one that assigns the AST nodes in the _children_ array
		# to instance variables as appropriate.
		def set_children(children)
			raise(NotImplementedError.new(self, 'set_children'))
		end
		
		# Virtual Method.  Any subclass of ASTNode should overwrite this
		# method with one that prints the AST as source code.
		def to_src
			raise(NotImplementedError.new(self, 'to_src'))
		end
	end
end
