# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/09/20
# Description:	This file contains an implementation of the visitor pattern.

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# An implementation of the visitor pattern.
	#
	# @see http://en.wikipedia.org/wiki/Visitor_pattern
	module Visitor
		
		#################
		# Class Methods #
		#################
		
		# A callback method that installs the necessary data structures and
		# class methods in classes that include the Visitor module.
		#
		# @return [void]
		def self.included(klass)
			klass.extend(ClassMethods)
			
			klass.install_icvars(Array.new)
		end
		
		module ClassMethods
			# @return [Array<Action>] Actions associated with this visitor.
			attr_reader :actions
			
			
			def inherited(klass)
				klass.install_icvars(@actions.clone)
			end
			
			# Installs instance class varialbes into a class.
			#
			# @return [void]
			def install_icvars(inherited_actions)
				@actions = inherited_actions
			end
			
			# The main method used to construct visitor classes.  When the
			# {#visit} method is called on an object the visitor will serach
			# through the list of actions defined using the {.on} method and
			# select the best one.  It will then call the block associated
			# with the action, passing in the object to be visited.
			#
			# @example Simple Usage
			#   on Integer { |i| puts i }
			#
			# @example Using Guards
			#   on Integer, guard: ->(i) {i  < 10} { puts "Less than 10" }
			#   on Integer, guard: ->(i) {i >= 10} { puts "Not less than 10" }
			#
			# @example Wrapped Actions
			#   def my_wrapper(o)
			#     common_settup
			#     yield(o)
			#     common_teardown
			#   end
			#   
			#   on Foo, wrapper: my_wrapper { |o| specific_stuff }
			#
			# @param [Class]	klass	The class that this action applies to.
			# @param [Hash]	opts		Options for this action.
			# @param [Proc]	block	Block to be executed when this action is selected to visit an object.
			#
			# @option opts [Proc]	guard	A proc that must evaluate to true if this action is to be considered.
			# @option opts [Symbol]	wrapper	Name of a method used to wrap this action.
			#
			# @return [void]
			def on(klass, opts = {}, &block)
				raise ArgumentError, 'The klass parameter was not a Class.' if not klass.is_a?(Class)
				
				@actions << Action.new(klass, opts[:guard], opts[:wrapper], block)
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		# Visit an object.
		#
		# The list of actions are first filtered using the class given as the
		# first argument to {.on} clauses and the action's guard clause.  The
		# Object.is_a? method is used for testing, so if a clause is defined
		# using a superclass it may be selected.
		#
		# Once all possible candidates are selected using this method the
		# visitor will select the best one using the following criteria:
		# 
		# * More specific actions are preferred.  An action defined for
		#   Integer will be selected over an action for Numeric when visiting
		#   an integer.
		# * An action with a guard statement is preferred over an action
		#   without a guard clause.
		#
		# If multiple actions are considered equally good the action that was
		# defined first will be used.
		#
		# @param [Object] object The object to visit.
		#
		# @return [Object] The result of the action selected by the visitor.
		def visit(object)
			# Find candidate matches.
			candidates = self.class.actions.select { |a| object.is_a?(a.klass) and (if a.guard then a.guard[object] else true end) }
			
			raise 'No actions defined for given object.' if candidates.empty?
			
			# Find the best candidate match.
			action =
			candidates.inject(candidates.pop) do |best, cur|
				# Situations in which a new action is better:
				#  * The object is an instance of the class in the current action and not one of its superclasses.
				#  * The current action's class is a subclass of the best action's class.
				#  * The current action has the same class as the best so far, but includes a guard.
				#
				# If two matches are equally good go with the first one
				# defined.
				
				better   = cur.klass.subclass_of?(best.klass)
				better ||= best.klass == cur.klass and best.guard.nil? and not cur.guard.nil?
		
				if better then cur else best end
			end
			
			# Visit the object.
			if action.wrapper
				# Create the instance exec cache if it doesn't exist.
				@iexec_cache ||= Hash.new
				
				# Create the instance exec callback if it isn't already cached.
				@iexec_cache[action] ||= ->(*args) { self.instance_exec(*args, &action.block) }
				
				# Call the wrapper with the object and the instance exec wrapped block.
				self.send(action.wrapper, object, &@iexec_cache[action])
				
			else
				self.instance_exec(object, &action.block)
			end
		end
		
		#################
		# Inner Classes #
		#################
		
		# A POD used to hold data about an action.
		Action = Struct.new(:klass, :guard, :wrapper, :block)
	end
end
