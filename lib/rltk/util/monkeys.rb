# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/08
# Description:	This file holds various monkey patches that make coding easier.

############
# Requires #
############

###########
# Methods #
###########

def check_type(o, type, blame = nil, strict = false)
	type_ok = if strict then o.instance_of?(type) else o.is_a?(type) end
	
	if type_ok
		o
	else
		if blame
			raise "Parameter #{blame} must be an instance of the #{type.name} class.  Received an instance of #{o.class.name}."
		else
			raise "Expected an object of type #{type.name}.  Received an instance of #{o.class.name}."
		end
	end
end

def check_array_type(array, type, blame = nil, strict = false)
	array.each do |o|
		type_ok = if strict then o.instance_of?(type) else o.is_a?(type) end
		
		if not type_ok
			if blame
				raise "Parameter #{blame} must contain instances of the #{type.name} class."
			else
				raise "Expected an object of type #{type.name}."
			end
		end
	end
end

#######################
# Classes and Modules #
#######################

class Object
	def returning(value)
		yield(value)
		value
	end
end

class Class
	def includes_module?(mod)
		self.included_modules.include?(mod)
	end
	
	def short_name
		self.name.split('::').last
	end
	
	def subclass_of?(klass)
		raise "The klass parameter must be an instance of Class." if not klass.is_a?(Class)
		
		if (superklass = self.superclass)
			superklass == klass or superklass.subclass_of?(klass)
		else
			false
		end
	end
end

class Integer
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
