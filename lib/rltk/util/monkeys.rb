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

# A helper method for type checking Ruby values.
#
# @param [Object]		o		Object to type check.
# @param [Class]		type		Class the object should be an instance of.
# @param [String, nil]	blame	Variable name to blame for failed type checks.
# @param [Boolean]		strict	Strict or non-strict checking.  Uses `instance_of?` and `is_a?` respectively.
#
# @raise [ArgumentError] An error is raise if the type checking fails.
#
# @return [Object] The object passed as parameter o.
def check_type(o, type, blame = nil, strict = false)
	type_ok = if strict then o.instance_of?(type) else o.is_a?(type) end
	
	if type_ok
		o
	else
		if blame
			raise ArgumentError, "Parameter #{blame} must be an instance of the #{type.name} class.  Received an instance of #{o.class.name}."
		else
			raise ArgumentError, "Expected an object of type #{type.name}.  Received an instance of #{o.class.name}."
		end
	end
end

# A helper method for type checking Ruby array values.
#
# @param [Array<Object>]	array	Array of objects to type check.
# @param [Class]		type		Class the objects should be an instance of.
# @param [String, nil]	blame	Variable name to blame for failed type checks.
# @param [Boolean]		strict	Strict or non-strict checking.  Uses `instance_of?` and `is_a?` respectively.
#
# @raise [ArgumentError] An error is raise if the type checking fails.
#
# @return [Object] The object passed in parameter o.
def check_array_type(array, type, blame = nil, strict = false)
	array.each do |o|
		type_ok = if strict then o.instance_of?(type) else o.is_a?(type) end
		
		if not type_ok
			if blame
				raise ArgumentError, "Parameter #{blame} must contain instances of the #{type.name} class."
			else
				raise ArgumentError, "Expected an object of type #{type.name}."
			end
		end
	end
end

#######################
# Classes and Modules #
#######################

# Monkey-patched Object class.
class Object
	# Simple implementation of the Y combinator.
	#
	# @param [Object] value Value to be returned after executing the provided block.
	#
	# @return [Object] The object passed in parameter value.
	def returning(value)
		yield(value)
		value
	end
end

# Monkey-patched Class class.
class Class
	# Checks for module inclusion.
	#
	# @param [Module] mod Module to check the inclusion of.
	def includes_module?(mod)
		self.included_modules.include?(mod)
	end
	
	# @return [String] Name of class without the namespace.
	def short_name
		self.name.split('::').last
	end
	
	# Checks to see if a Class object is a subclass of the given class.
	#
	# @param [Class] klass Class we are checking if this is a subclass of.
	def subclass_of?(klass)
		raise 'The klass parameter must be an instance of Class.' if not klass.is_a?(Class)
		
		if (superklass = self.superclass)
			superklass == klass or superklass.subclass_of?(klass)
		else
			false
		end
	end
end

# Monkey-patchec Integer class.
class Integer
	# @return [Boolean] This Integer as a Boolean value.
	def to_bool
		self != 0
	end
end

# Monkey-patched TrueClass class.
class TrueClass
	# @return [1]
	def to_i
		1
	end
end

# Monkey-patched FalseClass class.
class FalseClass
	# @return [0]
	def to_i
		0
	end
end
