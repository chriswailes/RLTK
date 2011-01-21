# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file provides a base Node class for ASTs.

module RLTK
	class ASTError < Exception; end
	
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
		
		alias :'key?' :'has_key?'
		
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
			raise(NotImplementedError.new(self, 'children='))
		end
		
		def delete(key)
			@notes.delete(key)
			self.children.each { |c| c.delete(key) }
		end
		
		def each
			self.children.each { |c| yield c }
		end
		
		def has_key?(key)
			@notes.has_key?(key)
		end
		
		def initialize
			@notes	= Hash.new()
			@parent	= nil
		end
		
		def map
			self.children = self.children.map { |c| yield c }
		end
		
		def root
			if @parent then @parent.root else self end
		end
	end
end
