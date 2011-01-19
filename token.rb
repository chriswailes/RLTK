# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains code having to do with tokens.

module RLTK
	class Token
		attr_reader :type
		attr_reader :value
		
		attr_reader :file_offset
		attr_reader :line_number
		attr_reader :line_offset_start
		attr_reader :line_offset_end
		
		alias :start :line_offset_start
		alias :end :line_offset_end
		
		def initialize(type, value, file_offset, line_number, line_offset_start, line_offset_end)
			@type	= type
			@value	= value
			
			@file_offset		= file_offset
			@line_number		= line_number
			@line_offset_start	= line_offset_start
			@line_offset_end	= line_offset_end
		end
		
		def to_s()
			"Token(#{self.type}, #{self.value})"
		end
	end
end

