# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2017/09/15
# Description: Helper functions for RLTK

module RLTK
	# Converts an object into an IO object as appropriate.
	#
	# @param [Object]  o     Object to be converted into an IO object.
	# @param [String]  mode  String representing the mode to open the IO object in.
	#
	# @return [IO, false] The IO object or false if a conversion wasn't possible.
	def self.get_io(o, mode = 'w')
		if o.is_a?(TrueClass)
			$stdout
		elsif o.is_a?(String)
			File.open(o, mode)
		elsif o.is_a?(IO)
			o
		else
			false
		end
	end
end
