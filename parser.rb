# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

require 'pp'

# Ruby Language Toolkit
require 'lexers/ebnf'

#######################
# Classes and Modules #
#######################

module RLTK
	class ParsingError < Exception; end
	class ParserConstructionError < Exception; end
	class InternalParserError < Exception; end
	
	class Parser
		def Parser.inherited(klass)
			klass.class_exec do
				@precs		= {:'!left' => 0, :'!right' => 0, :'!non' => 0}
				@proxy		= RuleProxy.new(self)
				@rules		= Hash.new {|h, k| h[k] = Array.new}
				@start_symbol	= nil
				@table		= nil
				@tokens		= nil
				
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
									f.puts("\tRule #{rule.id} #{rule.to_s}")
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
								
								state.actions.each do |sym, actions|
									actions.each do |action|
										f.puts("\tOn #{if sym then sym else 'any' end} #{action}")
									end
								end
								
								conflict = false
								
								f.puts
								f.puts("\t# CONFLICTS #")
								
								state.actions.keys.each do |sym|
									if sym.to_s == sym.to_s.upcase
									
										sandrs = state.on?(sym).select {|a| a.is_a?(Table::Shift) or a.is_a?(Table::Reduce)}
										
										if sandrs.length > 1
											conflict = true
											
											f.puts("\tOn #{if sym then sym else 'any' end}")
											
											sandrs.each do |a|
												f.puts("\t\t#{a}")
											end
											f.puts
										end
									end
								end
								
								f.puts("\tNone\n\n") if not conflict
							end
						end
					else
						File.open(explain_file, 'w') {|f| f.puts('Parser.explain called outside of finalize.')}
					end
				end
				
				def self.finalize(explain_file = nil)
					# Create our Transition Table.
					@table = Table.new
					
					# Grab the captured tokens from the proxy.
					@tokens = @proxy.tokens
					all_tokens = @tokens.keys
					
					# Add our starting state to the transition table.
					start_rule	= Rule.new(0, :'!start', [Token.new(:DOT), Token.new(:NONTERM, @start_symbol)])
					start_state	= Table::State.new(all_tokens, [start_rule])
					
					start_state.close(@rules)
					
					@table << start_state
					
					# Translate the precedence of rules from tokens to
					# (associativity, precedence) pairs.
					@rules.each_key do |key|
						if key.is_a?(Integer)
							@rules[key].prec = @precs[@rules[key].prec]
						end
					end
					
					# Build the rest of the transition table.
					@table.each do |state|
						#Transition states
						tstates = Hash.new {|h,k| h[k] = Table::State.new(all_tokens)}
						
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
								state.on(ttoken[1], Table::GoTo.new(id))
							else
								state.on(ttoken[1], Table::Shift.new(id))
							end
						end
						
						# Find the Accept and Reduce actions for this state.
						state.each do |item|
							if item.tokens[-1].type == :DOT
								if item.symbol == :'!start'
									state.on(:EOS, Table::Accept.new)
								else
									state.on_all(Table::Reduce.new(item.id))
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
					
					# Check the table.
					@table.check
					
					@rules.values.select {|o| o.is_a?(Rule)}.each {|rule| rule.clean}
				end
				
				def self.get_question(token)
					new_symbol	= ('!' + token.value.to_s.downcase + '_question').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @rules.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_question: | token
						
						# 1st (empty) production.
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) {|| nil }
						@rules[new_symbol] << (@rules[r.id] = r)
						
						# 2nd production
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|o| o}
						@rules[new_symbol] << (@rules[r.id] = r)
					end
					
					return new_token
				end
				
				def self.get_plus(token)
					new_symbol	= ('!' + token.value.to_s.downcase + '_plus').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @rules.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_plus: token | token token_plus
						
						# 1st production
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|t| [t]}
						@rules[new_symbol] << (@rules[r.id] = r)
						
						# 2nd production
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|t, tp| [t] + tp}
						@rules[new_symbol] << (@rules[r.id] = r)
					end
					
					return new_token
				end
				
				def self.get_star(token)
					new_symbol	= ('!' + token.value.to_s.downcase + '_star').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @rules.has_key?(new_token.value)
						# Add the items for the following productions:
						#
						# token_star: | token token_star
						
						# 1st (empty) production
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) {|| [] }
						@rules[new_symbol] << (@rules[r.id] = r)
						
						# 2nd production
						r = Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|t, ts| [t] + ts}
						@rules[new_symbol] << (@rules[r.id] = r)
					end
					
					return new_token
				end
				
				def self.left(*symbols)
					symbols.each do |s|
						if s.is_a?(Symbol) and s.to_s == s.to_s.upcase
							@precs[s] = [:left, @precs[:'!left'] += 1]
						else
							raise InternalParserError, 'Incorrect token specification given to the left directive.'
						end
					end
				end
				
				def self.nonassoc(*symbols)
					symbols.each do |s|
						if s.is_a?(Symbol) and s.to_s == s.to_s.upcase
							@precs[s] = [:non, @precs[:'!non'] += 1]
						else
							raise InternalParserError, 'Incorrect token specification given to the nonassoc directive.'
						end
					end
				end
				
				def self.precs
					@precs
				end
				
				def self.right(*symbols)
					symbols.each do |s|
						if s.is_a?(Symbol) and s.to_s == s.to_s.upcase
							@precs[s] = [:right, @precs[:'!right'] += 1]
						else
							raise InternalParserError, 'Incorrect token specification given to the right directive.'
						end
					end
				end
				
				def self.rule(symbol, expression = nil, precedence = nil, &action)
					# Convert the 'symbol' to a Symbol if it isn't already.
					symbol = symbol.to_sym if not symbol.is_a?(Symbol)
					
					# Set the start symbol if this is the first production
					# defined.
					@start_symbol ||= symbol
					
					# Set the symbol in the RuleProxy.
					@proxy.symbol = symbol
					
					# Collect rules by symbol and by rule id.
					if expression
						@rules[symbol] << (rule = @proxy.clause(expression, precedence, &action))
						
						@rules[rule.id] = rule
					else
						@rules[symbol] += (rules = @proxy.wrapper(&action))
						
						rules.each {|rule| @rules[rule.id] = rule}
					end
				end
				
				def self.rules
					@rules
				end
				
				def self.start(symbol)
					@start_symbol = symbol
				end
				
				def self.table
					@table
				end
				
				def self.tokens
					@tokens
				end
				
				####################
				# Instance Methods #
				####################
				
				def parse(tokens, verbose = false)
					v = if verbose then (verbose.class == String) ? File.open(verbose, 'a') : $stdout else nil end
					
					# Start out with one stack in state zero.
					processing	= [ParseStack.new]
					moving_on		= []
					
					# Iterate over the tokens.  We don't procede to the
					# next token until every stack is done with the
					# current one.
					tokens.each do |token|
					
						# Check to make sure this token as seen in the
						# grammar definition.
						if not self.class.tokens[token.type]
							raise ParsingError, 'Unexpected token.  Token not present in grammar definition.'
						end
						
						# If we don't have any active stacks the string
						# isn't in the language.
						if processing.length == 0
							raise ParsingError, 'String not in language.'
						end
						
						if verbose
							v.puts("Current token: #{token.type}#{if token.value then "(#{token.value})" end}")
						end
						
						# Iterate over the stacks until each one is done.
						until processing.empty?
							stack = processing.shift
							
							new_stacks = []
							
							# Get the available actions for this stack.
							actions = self.class.table[stack.state].on?(token.type)
							
							# Filter the actions based on precedence and
							# associativity.
							if self.class.precs[token.type] and actions.inject(true) {|m, a| if a.is_a?(Table::Reduce) then m and self.class.rules[a.id].prec else m end}
								max_prec = 0
								selected_action = nil
								
								actions.each do |a|
									assoc, prec = a.is_a?(Table::Shift) ? self.class.precs[token.type] : self.class.rules[a.id].prec
									
									if prec > max_prec or (prec == max_prec and assoc == (a.is_a?(Table::Shift) ? :right : :left))
										max_prec			= prec
										selected_action	= a
										
									elsif prec == max_prec and assoc == :nonassoc
										raise ParsingError, "Nonassociative token found during conflict resolution."
										
									end
								end
								
								actions = [selected_action]
							end
							
							actions.each do |action|
								new_stacks << (nstack = stack.copy)
								
								if verbose
									v.puts
									v.puts("Current state stack: #{nstack.state_stack.inspect}")
									v.puts("Action taken: #{action.to_s}")
								end
								
								if action.class == Table::Accept
									return nstack.result
								
								elsif action.class == Table::GoTo
									raise InternalParserError, 'GoTo action encountered when reading a token.'
								
								elsif action.class == Table::Reduce
									# Get the rule associated with this reduction.
									if not (rule = self.class.rules[action.id])
										raise InternalParserError, "No rule #{action.id} found."
									end
									
									nstack.push_output(rule.action.call(*nstack.pop(rule.action.arity)))
									
									if (goto = self.class.table[nstack.state].on?(rule.symbol))
										nstack.push_state(goto.id)
									else
										raise InternalParserError, "No GoTo action found in state #{nstack.state} after reducing by rule #{action.id}"
									end
									
								elsif action.class == Table::Shift
									nstack.push(action.id, token.value)
									
									moving_on << new_stacks.delete(nstack)
								end
							end
							
							processing += new_stacks
						end
						
						if verbose then v.puts("\n\n") end
						
						processing = moving_on
					end
				end
			end
		end
		
		class ParseStack
			attr_reader :state_stack
			
			def initialize(ostack = [], sstack = [0])
				@output_stack	= ostack
				@state_stack	= sstack
			end
			
			def copy
				ParseStack.new(Array.new(@output_stack), Array.new(@state_stack))
			end
			
			def push(state, o)
				@state_stack << state
				@output_stack << o
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
			
			def result
				if @output_stack.length == 1
					return @output_stack.last
				else
					raise InternalParserError, "The parsing stack should have 1 element on the output stack, not #{@utput_stack.length}."
				end
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
			
			attr_accessor :prec
			
			def initialize(id, symbol, tokens, precedence = nil, &action)
				@id		= id
				@symbol	= symbol
				@tokens	= tokens
				@prec	= precedence
				@action	= action || Proc.new {}
				
				if @prec and not @prec.is_a?(Symbol)
					raise ParserConstructionError, 'Non-Symbol object used to specify precedence.'
				end
				
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
			attr_reader :tokens
			attr_writer :symbol
			
			def initialize(parser)
				@parser = parser
				
				@lexer = EBNFLexer.new
				@rules = Array.new
				
				@rule_counter = 0
				@symbol = nil
				
				@tokens = Hash.new(false)
			end
			
			def clause(expression, precedence = nil, &action)
				tokens = @lexer.lex(expression)
				
				new_tokens = [Token.new(:DOT)]
				
				# Remove EBNF tokens and replace them with new productions.
				tokens.each_index do |i|
					ttype0 = tokens[i].type
					
					if ttype0 == :TERM or ttype0 == :NONTERM
						
						# Add this token to the @tokens hash.
						if ttype0 == :TERM
							@tokens[tokens[i].value] = true
						end
						
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
				
				# Check to make sure the action's arity matches the number
				# of tokens in the clause.
				if action.arity != new_tokens.length
					raise ParserConstructionError, 'Incorrect number of arguments to action.  Action arity must match the number of ' +
						'terminals and non-terminals in the clause.'
				end
				
				# If no precedence is specified use the precedence of the
				# last terminal in the production.
				if not precedence and new_tokens.length > 1
					new_tokens.reverse_each do |t|
						if t.type == :TERM
							precedence = t.value
							break
						end
					end
				end
				
				# Add the item to the current list.
				@rules << (rule = Rule.new(self.next_id, @symbol, new_tokens, precedence, &action))
				
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
			
			def check
				
			end
			
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
				
				def initialize(tokens, items = [])
					@id		= nil
					@items	= items
					@actions	= tokens.inject(Hash.new) { |h, t| h[t] = Array.new; h }
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
					if @actions.key?(symbol)
						@actions[symbol] << action
					else
						raise InternalParserError, 'Attempting to set action for token not seen in grammar definition.'
					end
				end
				
				def on_all(action)
					@actions.each { |k, v| v << action }
				end
				
				def on?(symbol)
					# If we are asking about a non-terminal we are looking
					# for a GoTo action, and should only return a single
					# action.
					if symbol.to_s == symbol.to_s.downcase
						if @actions[symbol].length > 1
							raise InternalParserError, "Multiple GoTo actions present for non-terminal symbol #{symbol} in state #{@id}."
						else
							@actions[symbol].first
						end
					else
						@actions[symbol]
					end
				end
			end
			
			class Action
				attr_reader :id
				
				def initialize(id = nil)
					@id = id
				end
			end
			
			class Accept < Action
				def to_s
					"Accept"
				end
			end
			
			class GoTo < Action
				def to_s
					"GoTo #{self.id}"
				end
			end
			
			class Reduce < Action
				def to_s
					"Reduce by Rule #{self.id}"
				end
			end
			
			class Shift < Action
				def to_s
					"Shift to State #{self.id}"
				end
			end
		end
	end
end
