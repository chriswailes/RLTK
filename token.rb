# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains code having to do with tokens.

#######################
# Classes and Modules #
#######################

module RLTK
	class Token
		attr_reader :type
		attr_reader :value
		
		attr_reader :stream_offset
		attr_reader :line_number
		attr_reader :line_offset_start
		attr_reader :line_offset_end
		
		alias :start :line_offset_start
		alias :end   :line_offset_end
		
		def initialize(type, value = nil, stream_offset = nil, line_number = nil, line_offset_start = nil, line_offset_end = nil)
			@type	= type
			@value	= value
			
			@stream_offset		= stream_offset
			@line_number		= line_number
			@line_offset_start	= line_offset_start
			@line_offset_end	= line_offset_end
		end
		
		def to_s()
			if value
				"#{self.type}(#{self.value})"
			else
				self.type.to_s
			end
		end
	end
end

