# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains code having to do with tokens.

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# The Token class is used to represent the output of a RLTK::Lexer and the
	# input of a RLTK::Parser.
	class Token
		attr_reader :type
		attr_reader :value
		
		attr_reader :stream_offset
		attr_reader :line_number
		attr_reader :line_offset
		
		alias :start :line_offset
		
		# Instantiates a new Token object with the values specified.
		def initialize(type, value = nil, stream_offset = nil, line_number = nil, line_offset = nil, length = nil)
			@type	= type
			@value	= value
			
			@stream_offset	= stream_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@length		= length
		end
		
		# Compares one token to another.  This only tests the token's _type_
		# and _value_ and not the location of the token in its source.
		def ==(other)
			self.type == other.type and self.value == other.value
		end
		
		# Returns a string representing the tokens _type_ and _value_.
		def to_s
			if value
				"#{self.type}(#{self.value})"
			else
				self.type.to_s
			end
		end
	end
end
