# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file holds various monkey patches that make coding easier.

############
# Requires #
############

#######################
# Classes and Modules #
#######################

class Object
	def returning(value)
		yield(value)
		value
	end
end

class Fixnum
	def to_bool
		self != 0
	end
end

class TrueClass
	def to_i
		1
	end
end

class FalseClass
	def to_i
		0
	end
end
