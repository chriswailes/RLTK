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
require File.join(File.dirname(__FILE__), 'token')

#######################
# Classes and Modules #
#######################

module RLTK
	class LexingError < Exception
		def initialize(streamstream_offset, line_number, line_offset, remainder)
			@stream_offset	= stream_offset
			@line_number	= line_number
			@line_offset	= line_offset
			@remainder	= remainder
		end
		
		def to_s()
			"#{super()}: #{@remainder}"
		end
	end
	
	class Lexer
		attr_accessor :start_state
		
		def Lexer.inherited(klass)
			klass.class_exec do
				@rules		= Hash.new {|h,k| h[k] = Array.new}
				@start_state	= :default
				
				#################
				# Class Methods #
				#################
				
				def self.rule(pattern, state = :default, flags = [], &action)
					#If no action is given we will set it to an empty
					#action.
					action ||= Proc.new() {}
					
					r = Rule.new(pattern, action, state, flags)
					
					if state == :ALL then @rules.each_key { |k| @rules[k] << r } else @rules[state] << r end
				end
				
				def self.rules()
					@rules
				end
				
				def self.start_state()
					@start_state
				end
				
				def self.start_state=(state)
					@start_state = state
				end
				
				####################
				# Instance Methods #
				####################
				
				def lex(string)
					#Set up the environment for this lexing pass.
					env = Environment.new(self.class.start_state())
					
					#Offset from start of stream.
					stream_offset = 0
				
					#Offset from the start of the line.
					line_offset = 0
					line_number = 1
					
					#Empty token list.
					@tokens = Array.new()
					
					#The scanner.
					scanner = StringScanner.new(string)
					
					#Start scanning the input string.
					until scanner.eos?
						match = nil
						
						#All rules for the currrent state need to be scanned so
						#that we find the longest match possible.
						self.class.rules()[env.state()].each do |rule|
							if (rule.flags - env.flags).empty?
								if txt = scanner.check(rule.pattern)
									if not match or match[0].length() < txt.length()
										match = [txt, rule]
									end
								end
							end
						end
						
						if match
							rule = match.last()
							
							txt = scanner.scan(rule.pattern)
							type, value = env.instance_exec(txt, &rule.action)
							
							if type
								@tokens << Token.new(type, value, stream_offset, line_number, line_offset, line_offset + txt.length()) 
							end
							
							#Advance our stat counters.
							stream_offset += txt.length()
							
							if (newlines = txt.count("\n")) > 0
								line_number += newlines
								line_offset  = 0
							else
								line_offset += txt.length()
							end
						else
							error = LexingError.new(stream_offset, line_number, line_offset, scanner.post_match())
							raise(error, 'Unable to match string with any of the given rules')
						end
					end
					
					return @tokens << Token.new(:EOS, nil, stream_offset, line_number)
				end
				
				def lex_file(file_name)
					file = File.open(file_name, 'r')
					
					lex(file.read())
				end
				
				def next_token()
					@tokens.shift()
				end
			end
		end
		
		#################
		# Inner Classes #
		#################
		
		class Environment
			attr_reader :flags
			
			def initialize(start_state)
				@state	= [start_state]
				@flags	= Array.new()
			end
			
			def add_state(state)
				@state << state
				
				nil
			end
			
			def pop_state()
				@state.pop()
				
				nil
			end
			
			def set_state(state)
				@state[-1] = state
				
				nil
			end
			
			def state()
				return @state.last()
			end
			
			def set_flag(flag)
				if not @flags.include?(flag)
					@flags << flag
				end
				
				nil
			end
			
			def unset_flag(flag)
				@flags.delete(flag)
				
				nil
			end
			
			def clear_flags()
				@flags = Array.new()
				
				nil
			end
		end
		
		class Rule
			attr_reader :action
			attr_reader :pattern
			attr_reader :flags
			
			def initialize(pattern, action, state, flags)
				@pattern	= pattern
				@action	= action
				@state	= state
				@flags	= flags
			end
		end
	end
end
