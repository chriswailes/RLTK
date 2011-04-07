# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file provides a base Node class for ASTs.

module RLTK
	class NotImplementedError < Exception
		def initialize(obj, method)
			@class	= obj.class
			@method	= method
		end
		
		def to_s
			"Function '#{@method}' not implemented for #{@class}."
		end
	end
	
	class ASTNode
		attr_accessor :parent
		
		def ==(other)
			self.children == other.children
		end
		
		def [](key)
			@notes[key]
		end
		
		def []=(key, value)
			@notes[key] = value
		end
		
		def children
			raise(NotImplementedError.new(self, 'children'))
		end
		
		def children=(children)
			self.set_children(children)
			
			children.each { |c| c.parent = self }
		end
		
		def delete_note(key)
			@notes.delete(key)
			self.children.each { |c| c.delete_note(key) }
		end
		
		def each
			self.children.each { |c| yield c }
		end
		
		def has_note?(key)
			@notes.has_key?(key)
		end
		
		alias :'note?' :'has_note?'
		
		def initialize
			if self.class == RLTK::Node
				raise Exception, 'Attempting to instantiate the RLTK::ASTNode class.'
			else
				@notes	= Hash.new()
				@parent	= nil
			end
		end
		
		def inspect
			raise(NotImplementedError.new(self, 'inspect'))
		end
		
		def map
			self.children = self.children.map { |c| yield c }
		end
		
		def root
			if @parent then @parent.root else self end
		end
		
		def set_children(children)
			raise(NotImplementedError.new(self, 'set_children'))
		end
		
		def to_src
			raise(NotImplementedError.new(self, 'to_src'))
		end
	end
end
