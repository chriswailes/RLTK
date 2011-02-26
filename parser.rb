# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

# Standard Library
require 'pp'

# Ruby Language Toolkit
require 'lexers/ebnf'

#######################
# Classes and Modules #
#######################

module RLTK
	class ParserError < Exception; end
	
	class Parser
		def Parser.inherited(klass)
			klass.class_exec do
				@proxy		= RuleProxy.new(self)
				@rules		= Hash.new {|h, k| h[k] = Array.new}
				@start_symbol	= nil
				@table		= nil
				
				#################
				# Class Methods #
				#################
				
				def self.explain(explain_file)
					if @proxy and @table
						File.open(explain_file, 'w') do |f|
							f.puts("##############" + '#' * self.name.length)
							f.puts("# Rules for #{self.name} #")
							f.puts("##############" + '#' * self.name.length)
							f.puts
							
							# Print the rules.
							@rules.keys.select {|k| k.is_a?(Symbol)}.each do |sym|
								@rules[sym].each do |rule|
									f.puts("\t#{rule.to_s}")
								end
								
								f.puts
							end
							
							f.puts("Start symbol: #{@start_symbol}")
							f.puts
							
							# Print the parse table.
							f.puts("###############")
							f.puts("# Parse Table #")
							f.puts("###############")
							f.puts
							
							@table.each do |state|
								f.puts("State #{state.id}:")
								
								max = state.items.inject(0) do |max, item|
									if item.symbol.to_s.length > max then item.symbol.to_s.length else max end
								end
								
								state.each do |item|
									f.puts("\t#{item.to_s(max, true)}")
								end
								
								f.puts
								f.puts("\t# ACTIONS #")
								
								state.actions.each do |token, actions|
									sym = if token then token[1] else nil end
									
									actions.each do |action|
										f.puts("\tOn #{if sym then sym else 'any' end} #{action}")
									end
								end
								
								f.puts
							end
						end
					else
						File.open(table_file, 'w') {|f| f.puts('Parser.explaine called outside of finalize.')}
					end
				end
				
				def self.finalize(explain_file = nil)
					# Create our Transition Table
					@table = Table.new
					
					# Add our starting state to the transition table.
					start_rule	= Rule.new(0, :'!start', [Token.new(:DOT), Token.new(:NONTERM, @start_symbol)])
					start_state	= Table::State.new([start_rule])
					
					start_state.close(@rules)
					
					@table << start_state
					
					# Build the rest of the transition table.
					@table.each do |state|
						#Transition states
						tstates = Hash.new {|h,k| h[k] = Table::State.new}
						
						#Bin each item in this set into reachable
						#transition states.
						state.each do |item|
							if (next_token = item.next_token)
								tstates[next_token.signature] << item.copy
							end
						end
						
						# For each transition state:
						#  1) Get transition token
						#  2) Advance dot
						#  3) Close it
						#  4) Get state id, and add transition
						tstates.each do |ttoken, tstate|
							tstate.each {|item| item.advance}
							
							tstate.close(@rules)
							
							id = @table << tstate
							
							# Add Goto and Shift actions.
							if ttoken[0] == :NONTERM
								state.on(ttoken, Table::GoTo.new(id))
							else
								state.on(ttoken, Table::Shift.new(id))
							end
						end
						
						# Find the Accept and Reduce actions for this state.
						state.each do |item|
							if item.tokens[-1].type == :DOT
								if item.symbol == :'!start'
									state.on([:TERM, :EOS], Table::Accept.new)
								else
									state.on(nil, Table::Reduce.new(item.id))
								end
							end
						end
					end
					
					# Print the table if requested.
					self.explain(explain_file) if explain_file
					
					# Remove references to the RuleProxy.
					@proxy = nil
					
					# Clean the resources we are keeping.
					@table.clean
					
					pp @rules
					
					@rules.values.select {|o| o.is_a?(Rule)}.each {|rule| rule.clean}
				end
				
				def self.get_question(token)
					new_symbol	= ('!' + token.value.to_s + '_question').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_question: | token
						
						# 1st (empty) production.
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) { nil }
						
						# 2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|v| v[0]}
					end
					
					return new_token
				end
				
				def self.get_plus(token)
					new_symbol	= ('!' + token.value.to_s + '_plus').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_plus: token | token token_plus
						
						# 1st production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|v| [v[0]]}
						
						# 2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.get_star(token)
					new_symbol	= ('!' + token.value.to_s + '_star').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_star: | token token_star
						
						# 1st (empty) production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) { [] }
						
						# 2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.rule(symbol, expression = nil, &action)
					# Convert the 'symbol' to a Symbol if it isn't already.
					symbol = symbol.to_sym if not symbol.is_a?(Symbol)
					
					# Set the start symbol if this is the first production
					# defined.
					@start_symbol ||= symbol
					
					# Set the symbol in the RuleProxy.
					@proxy.symbol = symbol
					
					# Collect rules by symbol and by rule id.
					if expression
						@rules[symbol] << (rule = @proxy.clause(expression, &action))
						
						@rules[rule.id] = rule
					else
						@rules[symbol] += (rules = @proxy.wrapper(&action))
						
						rules.each {|rule| @rules[rule.id] = rule}
					end
				end
				
				def self.start(symbol)
					@start_symbol = symbol
				end
				
				####################
				# Instance Methods #
				####################
				
				def parse(tokens)
					# Start out with one stack in state zero.
					stacks = [ParseStack.new]
					
					tokens.each do |token|
						new_stacks = []
						
						stacks.each do |stack|
							actions = @table[stack.state].on?(token.value)
							
							if actions.length == 0
								# Check to see if we removed the last stack.
								if stacks.length == 0
									raise ParserError, 'Out of actions.'
								end
							else
								actions.each do |action|
									new_stacks << (nstack = stack.clone)
									
									case action.class
										when Table::Accept
											raise ParserError, 'Accept action encountered on token other then EOS'
										
										when Table::GoTo
											raise ParserError, 'GoTo action encountered when reading a token.'
										
										when Table::Reduce
											# Get the rule associated with this reduction.
											if not (rule = @rules[action.id])
												raise ParserError, "No rule #{action.id} found."
											end
											
											nstack.push_output(rule.action.call(*nstack.pop(rule.action.arity)))
											
											gotos = @table[nstack.state].on?(rule.symbol).select {|a| a.is_a?(Table::GoTo)}
											
											if gotos.length == 1
												nstack.push_state(gotos.first.id)
											else
												raise ParserError, 'Multiple GoTos encountered after a Reduce action.'
											end
										
										when Table::Shift
											new_stack.push_state(action.id)
									end
								end
							end
						end
						
						stacks = new_stacks
					end
					
					# Check to see if any of the stacks are in an accept
					# state.  If multiple stacks are in accept states throw
					# an error.  Otherwise reutrn the result of the user
					# actions.
					stacks.inject(nil) do |result, stack|
						if @table[stack.state].on?([:TERM, :EOS])
							if result
								raise ParserError, 'Multiple derivations possible.'
							else
								stack.output_stack.first
							end
						else
							result
						end
					end
				end
			end
		end
		
		class ParseStack
			def initalize(other)
				@output_stack	= [ ]
				@state_stack	= [0]
			end
			
			def push_output(o)
				@output_stack << o
			end
			
			def push_state(state)
				@state_stack << state
			end
			
			def pop(n = 1)
				@state_stack.pop(n)
				
				@output_stack.pop(n)
			end
			
			def state
				@state_stack.last
			end
		end
		
		class Rule
			attr_reader :id
			attr_reader :symbol
			attr_reader :tokens
			attr_reader :action
			
			def initialize(id, symbol, tokens, &action)
				@id		= id
				@symbol	= symbol
				@tokens	= tokens
				@action	= action || Proc.new {}
				
				@dot_index = @tokens.index {|t| t.type == :DOT}
			end
			
			def ==(other)
				self.action == other.action and self.tokens == other.tokens
			end
			
			def advance
				if (index = @dot_index) < @tokens.length - 1
					@tokens[index], @tokens[index + 1] = @tokens[index + 1], @tokens[index]
					@dot_index += 1
				end
			end
			
			def clean
				@dot_index = @tokens = nil
			end
			
			def copy
				Rule.new(@id, @symbol, @tokens.clone, &@action)
			end
			
			def next_token
				@tokens[@dot_index + 1]
			end
			
			def to_s(padding = 0, item_mode = false)
				"#{format("%-#{padding}s", @symbol)} -> #{@tokens.map{|t| if t.type == :DOT and item_mode then '·' else t.value end}.join(' ')}"
			end
		end
		
		class RuleProxy
			attr_writer :symbol
			
			def initialize(parser)
				@parser = parser
				
				@lexer = EBNFLexer.new
				@rules = Array.new
				
				@rule_counter = 0
				@symbol = nil
			end
			
			def clause(expression, &action)
				tokens = @lexer.lex(expression)
				
				new_tokens = [Token.new(:DOT)]
				
				# Remove EBNF tokens and replace them with new productions.
				tokens.each_index do |i|
					ttype0 = tokens[i].type
					
					if ttype0 == :TERM or ttype0 == :NONTERM
						if i + 1 < tokens.length
							ttype1 = tokens[i + 1].type
							
							new_tokens <<
							case tokens[i + 1].type
								when :'?'
									@parser.get_question(tokens[i])
								
								when :*
									@parser.get_star(tokens[i])
								
								when :+
									@parser.get_plus(tokens[i])
								
								else
									tokens[i]
							end
						else
							new_tokens << tokens[i]
						end
					end
				end
				
				# Add the item to the current list.
				@rules << (rule = Rule.new(self.next_id, @symbol, new_tokens, &action))
				
				# Return the item from this clause.
				return rule
			end
			
			def next_id
				@rule_counter += 1
			end
			
			def wrapper(&block)
				@rules = Array.new
				
				self.instance_exec(&block)
				
				return @rules
			end
		end
		
		class Table
			attr_reader :rows
			
			def initialize
				@states = Array.new
			end
			
			def [](index)
				@states[index]
			end
			
			def add_state(state)
				if (id = @states.index(state))
					id
				else
					state.id = @states.length
					
					@states << state
					
					@states.length - 1
				end
			end
			
			alias :<< :add_state
			
			def clean
				@states.each {|state| state.clean}
			end
			
			def each
				@states.each {|r| yield r}
			end
			
			class State
				attr_accessor	:id
				attr_reader	:items
				attr_reader	:actions
				
				def initialize(items = [])
					@id		= nil
					@items	= items
					@actions	= Hash.new {|h,k| h[k] = Array.new}
				end
				
				def ==(other)
					self.items == other.items
				end
				
				def append(item)
					if not @items.include?(item) then @items << item end
				end
				
				alias :<< :append
				
				def clean
					@items = nil
				end
				
				def close(rules)
					self.each do |item|
						if (next_token = item.next_token) and next_token.type == :NONTERM
							rules[next_token.value].each {|r| self << r}
						end
					end
				end
				
				def each
					@items.each {|item| yield item}
				end
				
				def on(symbol, action)
					@actions[symbol] << action
				end
				
				def on?(symbol)
					@actions[nil] | @actions[symbol]
				end
			end
			
			class Action
				attr_reader :id
				
				def initialize(id = nil)
					@id = id
				end
				
				def to_s
					"#{self.class.name.split('::').last}" + if @id then " #{@id}" else '' end
				end
			end
			
			class Accept	< Action; end
			class GoTo	< Action; end
			class Reduce	< Action; end
			class Shift	< Action; end
		end
	end
end
