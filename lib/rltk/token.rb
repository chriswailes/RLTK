# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains code having to do with tokens.

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# The StreamPosition class is used to indicate the position of a token or
	# other text inside a stream.
	class StreamPosition
		attr_accessor :stream_offset
		attr_accessor :line_number
		attr_accessor :line_offset
		attr_accessor :length
		
		attr_accessor :file_name
		
		alias :start :line_offset
		
		# Instantiates a new StreamPosition object with the values specified.
		def initialize(stream_offset = 0, line_number = 0, line_offset = 0, length = 0, file_name = nil)
			@stream_offset	= stream_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@length		= length
			@file_name	= file_name
		end
	end
	
	# The Token class is used to represent the output of a RLTK::Lexer and the
	# input of a RLTK::Parser.
	class Token
		attr_reader :type
		attr_reader :value
		
		# The StreamPosition object associated with this token.
		attr_reader :position
		
		# Instantiates a new Token object with the values specified.
		def initialize(type, value = nil, position = nil)
			@type	= type
			@value	= value
			
			@position	= position
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
