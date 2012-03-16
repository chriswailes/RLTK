# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/17
# Description:	This file contains the base class for lexers that use RLTK.

############
# Requires #
############

# Standard Library
require 'strscan'

# Ruby Language Toolkit
require 'rltk/token'

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# A LexingError exception is raised when an input stream contains a
	# substring that isn't matched by any of a lexer's rules.
	class LexingError < StandardError
		def initialize(stream_offset, line_number, line_offset, remainder)
			@stream_offset	= stream_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@remainder	= remainder
		end
		
		def to_s()
			"#{super()}: #{@remainder}"
		end
	end
	
	# The Lexer class may be sub-classed to produce new lexers.  These lexers
	# have a lot of features, and are described in the main documentation.
	class Lexer
		
		# Called when the Lexer class is sub-classed, this method adds a
		# LexerCore to the new class, and installs some needed class and
		# instance methods.
		def Lexer.inherited(klass)
			klass.class_exec do
				@core = LexerCore.new
				
				# Returns this class's LexerCore object.
				def self.core
					@core
				end
				
				# Lexes the given string using a newly instantiated
				# environment.
				def self.lex(str)
					@core.lex(str, self::Environment.new(@core.start_state))
				end
				
				# Lexes the contents of the given file using a newly
				# instantiated environment.
				def self.lex_file(file_name)
					@core.lex_file(file_name, self::Environment.new(@core.start_state))
				end
				
				# Routes method calls to the new subclass to the LexerCore
				# object.
				def self.method_missing(method, *args, &proc)
					@core.send(method, *args, &proc)
				end
				
				# Instantiates a new lexer and creates an environment to be
				# used for subsequent calls.
				def initialize
					@env = self.class::Environment.new(self.class.core.start_state)
				end
				
				# Returns the environment used by an instantiated lexer.
				def env
					@env
				end
				
				# Lexes a string using the encapsulated environment.
				def lex(string)
					self.class.core.lex(string, @env)
				end
				
				# Lexes a file using the encapsulated environment.
				def lex_file(file_name)
					self.class.core.lex_file(file_name, @env)
				end
			end
		end
		
		#################
		# Inner Classes #
		#################
		
		# The LexerCore class provides most of the functionality of the Lexer
		# class.  A LexerCore is instantiated for each subclass of Lexer,
		# thereby allowing multiple lexers to be defined inside a single Ruby
		# program.
		class LexerCore
			attr_reader :start_state
			
			# Instantiate a new LexerCore object.
			def initialize
				@match_type	= :longest
				@rules		= Hash.new {|h,k| h[k] = Array.new}
				@start_state	= :default
			end
			
			# Lex _string_, using _env_ as the environment.  This method will
			# return the array of tokens generated by the lexer with a token
			# of type EOS (End of Stream) appended to the end.
			def lex(string, env, file_name = nil)
				# Offset from start of stream.
				stream_offset = 0
			
				# Offset from the start of the line.
				line_offset = 0
				line_number = 1
				
				# Empty token list.
				tokens = Array.new
				
				# The scanner.
				scanner = StringScanner.new(string)
				
				# Start scanning the input string.
				until scanner.eos?
					match = nil
					
					# If the match_type is set to :longest all of the
					# rules for the current state need to be scanned
					# and the longest match returned.  If the
					# match_type is :first, we only need to scan until
					# we find a match.
					@rules[env.state].each do |rule|
						if (rule.flags - env.flags).empty?
							if txt = scanner.check(rule.pattern)
								if not match or match.first.length < txt.length
									match = [txt, rule]
									
									break if @match_type == :first
								end
							end
						end
					end
					
					if match
						rule = match.last
						
						txt = scanner.scan(rule.pattern)
						type, value = env.rule_exec(rule.pattern.match(txt), txt, &rule.action)
						
						if type
							pos = StreamPosition.new(stream_offset, line_number, line_offset, txt.length, file_name)
							tokens << Token.new(type, value, pos) 
						end
						
						# Advance our stat counters.
						stream_offset += txt.length
						
						if (newlines = txt.count("\n")) > 0
							line_number += newlines
							line_offset  = 0
						else
							line_offset += txt.length()
						end
					else
						error = LexingError.new(stream_offset, line_number, line_offset, scanner.post_match)
						raise(error, 'Unable to match string with any of the given rules')
					end
				end
				
				return tokens << Token.new(:EOS)
			end
			
			# A wrapper function that calls ParserCore.lex on the
			# contents of a file.
			def lex_file(file_name, env)
				File.open(file_name, 'r') { |f| lex(f.read, env, file_name) }
			end
			
			# Used to tell a lexer to use the first match found instead
			# of the longest match found.
			def match_first
				@match_type = :first
			end
			
			# This method is used to define a new lexing rule.  The
			# first argument is the regular expression used to match
			# substrings of the input.  The second argument is the state
			# to which the rule belongs.  Flags that need to be set for
			# the rule to be considered are specified by the third
			# argument.  The last argument is a block that returns a
			# type and value to be used in constructing a Token. If no
			# block is specified the matched substring will be
			# discarded and lexing will continue.
			def rule(pattern, state = :default, flags = [], &action)
				# If no action is given we will set it to an empty
				# action.
				action ||= Proc.new() {}
				
				pattern = Regexp.new(pattern) if pattern.is_a?(String)
				
				r = Rule.new(pattern, action, state, flags)
				
				if state == :ALL then @rules.each_key { |k| @rules[k] << r } else @rules[state] << r end
			end
			
			alias :r :rule
			
			# Changes the starting state of the lexer.
			def start(state)
				@start_state = state
			end
		end
		
		# All actions passed to LexerCore.rule are evaluated inside an
		# instance of the Environment class or its subclass (which must have
		# the same name).  This class provides functions for manipulating
		# lexer state and flags.
		class Environment
			
			# The flags currently set in this environment.
			attr_reader :flags
			
			# The Match object generated by a rule's regular expression.
			attr_accessor :match
			
			# Instantiates a new Environment object.
			def initialize(start_state, match = nil)
				@state	= [start_state]
				@match	= match
				@flags	= Array.new
			end
			
			# This function will instance_exec a block for a rule after
			# setting the match value.
			def rule_exec(match, txt, &block)
				self.match = match
				
				self.instance_exec(txt, &block)
			end
			
			# Pops a state from the state stack.
			def pop_state
				@state.pop
				
				nil
			end
			
			# Pushes a new state onto the state stack.
			def push_state(state)
				@state << state
				
				nil
			end
			
			# Sets the value on the top of the state stack.
			def set_state(state)
				@state[-1] = state
				
				nil
			end
			
			# Returns the current state.
			def state
				return @state.last
			end
			
			# Sets a flag in the current environment.
			def set_flag(flag)
				if not @flags.include?(flag)
					@flags << flag
				end
				
				nil
			end
			
			# Unsets a flag in the current environment.
			def unset_flag(flag)
				@flags.delete(flag)
				
				nil
			end
			
			# Unsets all flags in the current environment.
			def clear_flags
				@flags = Array.new
				
				nil
			end
		end
		
		# The Rule class is used simply for data encapsulation.
		class Rule
			attr_reader :action
			attr_reader :pattern
			attr_reader :flags
			
			# Instantiates a new Rule object.
			def initialize(pattern, action, state, flags)
				@pattern	= pattern
				@action	= action
				@state	= state
				@flags	= flags
			end
		end
	end
end
