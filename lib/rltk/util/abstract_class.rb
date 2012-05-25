# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/20
# Description:	This file holds an implementation of an AbstractClass module.

# A module used for making abstract classes.  Any class that includes this
# module will not be able to be instantiated directly.
module AbstractClass
	# Callback method for when this module is included.
	#
	# @param [Class] klass The Class object for the including class.
	def self.included(klass)
		klass.instance_exec do
			@abstract_class = klass
			
			def self.new(*args)
				if self == @abstract_class
					raise "Instantiating abstract class #{self} is not allowed."
				else
					super
				end
			end
		end
	end
end
