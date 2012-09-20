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
	#
	# TODO: Add support for handling common functionality between different visitor clauses.
	class Visitor
		
		#################
		# Class Methods #
		#################
		
		class << self
			attr_reader :actions
			
			def inherited(klass)
				klass.install_icvars(if self == RLTK::Visitor then [] else @actions.clone end)
			end
			
			def install_icvars(inherited_actions)
				@actions = inherited_actions
			end
			
			def on(klass, guard = nil, &block)
				@actions << Action.new(klass, guard, block)
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		def visit(object)
			# Find candidate matches.
			candidates = self.class.actions.select { |a| object.is_a?(a.klass) and (if a.guard then a.guard[object] else true end) }
			
			raise 'No actions defined for given object.' if candidates.empty?
			
			# Find the best candidate match.
			# NOTE: If two matches are equally good go with the first one defined.
			# FIXME: Add a case for when the klasses are the same but one has a guard.
			match =
			candidates.inject(candidates.pop) do |best, cur|
				if (object.instance_of?(cur.klass) and not object.instance_of?(best.klass)) or cur.klass.subclass_of?(best.klass)
					cur
				end
			end
			
			# Visit the object.
			self.instance_exec(object, &match.block)
		end
		
		#################
		# Inner Classes #
		#################
		
		class Action
			attr_reader :klass
			attr_reader :guard
			attr_reader :block
			
			def initialize(klass, guard, block)
				@klass = klass
				@guard = guard
				@block = block
			end	
		end
	end
end
