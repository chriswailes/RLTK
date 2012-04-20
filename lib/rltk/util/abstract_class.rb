# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/20
# Description:	This file holds an implementation of an AbstractClass module.

module AbstractClass
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
