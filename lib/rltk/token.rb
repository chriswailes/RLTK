# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/01/17
# Description: This file contains code having to do with tokens.

#######################
# Classes and Modules #
#######################

module RLTK
	# The StreamPosition class is used to indicate the position of a token or
	# other text inside a stream.
	class StreamPosition
		# @return [Integer]
		attr_accessor :stream_offset

		# @return [Integer]
		attr_accessor :line_number

		# @return [Integer]
		attr_accessor :line_offset

		# @return [Integer]
		attr_accessor :length

		# @return [String]
		attr_accessor :file_name

		alias :start :line_offset

		# Instantiates a new StreamPosition object with the values specified.
		#
		# @param [Integer]      stream_offset  The position from the beginning of the stream.
		# @param [Integer]      line_number    The number of newlines since the beginning of the file.
		# @param [Integer]      line_offset    The offset of this token from the beginning of the current line.
		# @param [Integer]      length         The length of the text of the token.
		# @param [String, nil]  file_name      The name of the file being lexed.
		def initialize(stream_offset = 0, line_number = 0, line_offset = 0, length = 0, file_name = nil)
			@stream_offset = stream_offset
			@line_number   = line_number
			@line_offset   = line_offset
			@length        = length
			@file_name     = file_name
		end
	end

	# The Token class is used to represent the output of a RLTK::Lexer and the
	# input of a RLTK::Parser.
	class Token
		# @return [Symbol]
		attr_reader :type

		# @return [Symbol]
		attr_reader :value

		# @return [StreamPosition] StreamPosition object associated with this token.
		attr_reader :position

		# Instantiates a new Token object with the values specified.
		#
		# @param [Symbol]               type      A symbol representing the type of this Token.
		# @param [Object, nil]          value     A value associated with this token.
		# @param [StreamPosition, nil]  position  The position of the token in a stream.
		def initialize(type, value = nil, position = nil)
			@type     = type
			@value    = value
			@position = position
		end

		# Compares one token to another.  This only tests the token's *type*
		# and *value* and not the location of the token in its source.
		#
		# @param  [Token]  other  Another Token to compare to.
		#
		# @return [Boolean]
		def ==(other)
			self.type == other.type and self.value == other.value
		end

		# @return  [String]  String representing the tokens *type* and *value*.
		def to_s
			if value
				"#{self.type}(#{self.value})"
			else
				self.type.to_s
			end
		end
	end
end
