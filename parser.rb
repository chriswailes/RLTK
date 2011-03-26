# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

# Ruby Language Toolkit
require 'cfg'

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
				@core = ParserCore.new
				
				def self.method_missing(method, *args, &proc)
					@core.send(method, *args, &proc)
				end
				
				def initialize
					@env = Environment.new
				end
				
				def parse(tokens, verbose = false)
					self.class.parse(tokens, @env, verbose)
				end
			end
		end
		
		class Environment; end
		
		class ParserCore
			def initialize
				@curr_lhs		= nil
				@curr_prec	= nil
				
				@conflicts	= Hash.new {|h, k| h[k] = Array.new}
				@grammar		= CFG.new
				@lh_sides		= Hash.new
				@procs		= Array.new
				@start_symbol	= nil
				@states		= Array.new
				
				@prec_counts	= {:left => 0, :right => 0, :non => 0}
				@rule_precs	= Array.new
				@token_precs	= Hash.new
				
				@grammar.callback do |r, type, num|
					@procs[r.id] =
						if type == :*
							if num == :first
								Proc.new { || [] }
							else
								Proc.new { |o, os| [o] + os }
							end
						elsif type == :+
							if num == :first
								Proc.new { |o| o }
							else
								Proc.new { |o, os| [o] + os }
							end
						elsif type == :'?'
							if num == :first
								Proc.new { || nil }
							else
								Proc.new { |o| o }
							end
						end
					
					@rule_precs[r.id] = r.last_terminal
				end
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
			
			def check
				@states.each do |state|
					state.actions.each do |sym, actions|
						if CFG::is_terminal?(sym)
							# Here we check actions for terminals.
							
							reduces	= 0
							shifts	= 0
							
							actions.each do |action|
								if action.is_a?(Accept)
									if sym != :EOS
										raise ParserConstructionError, "Accept action found for terminal #{sym} in state #{state.id}."
									end
									
								elsif action.is_a?(Reduce)
									reduces += 1
									
								elsif action.is_a?(Shift)
									shifts += 1
									
								else
									raise ParserConstructionError, "Object of type #{action.class} found in actions for terminal " +
										"#{sym} in state #{state.id}."
									
								end
							end
							
							if shifts > 1
								raise ParserConstructionError, "Multiple shifts found for terminal #{sym} in state #{state.id}."
								
							elsif shifts == 1 and reduces > 0
								self.inform_conflict(state.id, :SR, sym)
								
							elsif reduces > 1
								self.inform_conflict(state.id, :RR, sym)
								
							end
						else
							# Here we check actions for non-terminals.
							
							if actions.length > 1
								raise ParserConstructionError, "State #{state.id} has multiple GoTo actions for non-terminal #{sym}."
								
							elsif actions.length == 1 and not actions.first.is_a?(GoTo)
								puts actions.first
								raise ParserConstructionError, "State #{state.id} has non-GoTo action for non-terminal #{sym}."
								
							end
						end
					end
				end
			end
			
			def clause(expression, precedence = nil, &action)
				# Use the curr_prec only if it isn't overridden for this
				# clause.
				precedence ||= @curr_prec
				
				action ||= Proc.new { || }
				
				rule = @grammar.clause(expression)
				
				# Check to make sure the action's arity matches the number
				# of symbols on the right-hand side.
				if action.arity != rule.rhs.length
					raise ParserConstructionError, 'Incorrect number of arguments to action.  Action arity must match the number of ' +
						'terminals and non-terminals in the clause.'
				end
				
				# Add the action to our proc list.
				@procs[rule.id] = action

				# If no precedence is specified use the precedence of the
				# last terminal in the production.
				@rule_precs[rule.id] = precedence || rule.last_terminal
			end
			
			def clean
				# We've told the developer about conflicts by now.
				@conflicts = nil
				
				# Drop the grammar.
				@grammar = nil
				
				# Drop the items from each of the states.
				@states.each { |state| state.clean }
			end
			
			def explain(explain_file)
				if @grammar and not @states.empty?
					File.open(explain_file, 'w') do |f|
						f.puts("#########")
						f.puts("# Rules #")
						f.puts("#########")
						f.puts
						
						# Print the rules.
						@grammar.rules.each do |sym, rules|
							rules.each do |rule|
								f.print("\tRule #{rule.id}: #{rule.to_s}")
								
								if (prec = @rule_precs[rule.id])
									f.print(" : (#{prec.first} , #{prec.last})")
								end
								
								f.puts
							end
							
							f.puts
						end
						
						f.puts("##########")
						f.puts("# Tokens #")
						f.puts("##########")
						f.puts
						
						@grammar.terms.each do |term|
							f.print("\t#{term}")
							
							if (prec = @token_precs[term])
								f.print(" : (#{prec.first}, #{prec.last})")
							end
							
							f.puts
						end
						
						f.puts
						
						f.puts("#####################")
						f.puts("# Table Information #")
						f.puts("#####################")
						f.puts
						
						f.puts("\tStart symbol: #{@start_symbol}")
						f.puts
						
						f.puts("\tTotal number of states: #{@states.length}")
						f.puts
						
						f.puts("\tTotal conflicts: #{@conflicts.values.flatten(1).length}")
						f.puts
						
						@conflicts.each do |state_id, conflicts|
							f.puts("\tState #{state_id} has #{conflicts.length} conflict(s)")
						end
						
						f.puts if not @conflicts.empty?
						
						# Print the parse table.
						f.puts("###############")
						f.puts("# Parse Table #")
						f.puts("###############")
						f.puts
						
						@states.each do |state|
							f.puts("State #{state.id}:")
							f.puts
							
							f.puts("\t# ITEMS #")
							max = state.items.inject(0) do |max, item|
								if item.lhs.to_s.length > max then item.lhs.to_s.length else max end
							end
							
							state.each do |item|
								f.puts("\t#{item.to_s(max)}")
							end
							
							f.puts
							f.puts("\t# ACTIONS #")
							
							state.actions.keys.sort {|a,b| a.to_s <=> b.to_s}.each do |sym|
								state.actions[sym].each do |action|
									f.puts("\tOn #{sym} #{action}")
								end
							end
							
							f.puts
							f.puts("\t# CONFLICTS #")
							
							if @conflicts[state.id].length == 0
								f.puts("\tNone\n\n")
							else
								@conflicts[state.id].each do |conflict|
									type, sym = conflict
									
									f.print("\t#{if type == :SR then "Shift/Reduce" else "Reduce/Reduce" end} conflict")
									
									f.puts(" on #{sym}")
								end
								
								f.puts
							end
						end
					end
				else
					raise ParserConstructionError, 'Parser.explain called outside of finalize.'
				end
			end
			
			def finalize(explain_file = nil)
				# Grab all of the symbols that comprise the grammar (besides
				# the start symbol).
				@symbols = @grammar.symbols
				
				# Add our starting state to the state list.
				start_rule	= @grammar.rule(:start, @start_symbol.to_s).first
				start_state	= State.new(@symbols, [start_rule.to_item])
				
				start_state.close(@grammar.rules)
				
				self.add_state(start_state)
				
				# Translate the precedence of rules from tokens to
				# (associativity, precedence) pairs.
				
				@rule_precs.each_with_index do |prec, id|
					@rule_precs[id] = @token_precs[prec]
				end
				
				# Build the rest of the transition table.
				@states.each do |state|
					#Transition states.
					tstates = Hash.new { |h,k| h[k] = State.new(@symbols) }
					
					#Bin each item in this set into reachable transition
					#states.
					state.each do |item|
						if (next_symbol = item.next_symbol)
							tstates[next_symbol] << item.copy
						end
					end
					
					# For each transition state:
					#  1) Get transition symbol
					#  2) Advance dot
					#  3) Close it
					#  4) Get state id and add transition
					tstates.each do |symbol, tstate|
						tstate.each { |item| item.advance }
						
						tstate.close(@grammar.rules)
						
						id = self.add_state(tstate)
						
						# Add Goto and Shift actions.
						state.on(symbol, CFG::is_nonterminal?(symbol) ? GoTo.new(id) : Shift.new(id))
					end
					
					# Find the Accept and Reduce actions for this state.
					state.each do |item|
						if item.at_end
							if item.lhs == :start
								state.on(:EOS, Accept.new)
							else
								state.on_any(Reduce.new(item.id))
							end
						end
					end
				end
				
				# Build the rule.id -> rule.lhs map.
				@grammar.rules(:id).to_a.inject(@lh_sides) do |h, pair|
					id, rule = pair
					
					h[id] = rule.lhs
					
					h
				end
				
				# Prune the parsing table for unnecessary reduce actions.
				self.prune
				
				# Check the parser for inconsistencies.
				self.check
				
				# Print the table if requested.
				self.explain(explain_file) if explain_file
				
				# Clean the resources we are keeping.
				self.clean
			end
			
			def grammar_prime
				if not @grammar_prime
					@grammar_prime = CFG.new
					
					@states.each do |state|
						state.each do |item|
							lhs = "#{state.id}_#{item.next_symbol}".to_sym
							
							next unless CFG::is_nonterminal?(item.next_symbol) and not @grammar_prime.rules.keys.include?(lhs)
							
							@grammar.rules[item.next_symbol].each do |rule|
								rhs = ""
								
								cstate = state
								
								rule.rhs.each do |symbol|
									rhs += "#{cstate.id}_#{symbol} "
									
									cstate = @states[cstate.on?(symbol).first.id]
								end
								
								@grammar_prime.rule(lhs, rhs)
							end
						end
					end
				end
				
				@grammar_prime
			end
			
			def inform_conflict(state_id, type, sym)
				@conflicts[state_id] << [type, sym]
			end
			
			def left(*symbols)
				prec_level = @prec_counts[:left] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:left, prec_level]
				end
			end
			
			def nonassoc(*symbols)
				prec_level = @prec_counts[:non] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:non, prec_level]
				end
			end
			
			def parse(tokens, env = Environment.new, verbose = false)
				v = if verbose then (verbose.class == String) ? File.open(verbose, 'a') : $stdout else nil end
				
				if v
					v.puts("Input tokens:")
					v.puts(tokens.map { |t| t.type }.inspect)
					v.puts
				end
				
				# Start out with one stack in state zero.
				processing	= [ParseStack.new]
				moving_on		= []
				
				# Iterate over the tokens.  We don't procede to the
				# next token until every stack is done with the
				# current one.
				tokens.each do |token|
				
					# Check to make sure this token was seen in the
					# grammar definition.
					if not @symbols.include?(token.type)
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
						actions = @states[stack.state].on?(token.type)
						
						actions.each do |action|
							new_stacks << (nstack = stack.copy)
							
							if verbose
								v.puts
								v.puts("Current state stack: #{nstack.state_stack.inspect}")
								v.puts("Action taken: #{action.to_s}")
							end
							
							if action.is_a?(Accept)
								return nstack.result
							
							elsif action.is_a?(GoTo)
								raise InternalParserError, 'GoTo action encountered when reading a token.'
							
							elsif action.is_a?(Reduce)
								
								# Get the rule associated with this reduction.
								if not (rule_proc = @procs[action.id])
									raise InternalParserError, "No rule #{action.id} found."
								end
								
								result = env.instance_exec(*nstack.pop(rule_proc.arity), &rule_proc)
								
								nstack.push_output(result)
								
								if (goto = @states[nstack.state].on?(@lh_sides[action.id]).first)
									nstack.push_state(goto.id)
								else
									raise InternalParserError, "No GoTo action found in state #{nstack.state} " +
										"after reducing by rule #{action.id}"
								end
								
							elsif action.is_a?(Shift)
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
			
			def prune
				symbols = @grammar.terms
				
				# Initialize our empty lookahead table.
				lookaheads = Hash.new { |h,k| h[k] = Hash.new { |h,k| h[k] = Array.new } }
				
				self.grammar_prime.nonterms.each do |gp_sym|
					
					# Get the State id and grammar symbol.
					sid, g_sym = gp_sym.to_s.split('_')
					
					# Get the follow set for the nonterminal in
					# grammar_prime.
					gp_follows = self.grammar_prime.follow_set(gp_sym)
					
					# Translate those follow sets into the lookahead sets
					# for the grammar.
					lookaheads[sid][g_sym.to_sym] |= gp_follows.map { |sym| sym.to_s.split('_').last }
				end
				
				@states.each do |state|
					
					#~puts "Pruning actions for state #{state.id}."
					
					#####################
					# Lookahead Pruning #
					#####################
					
					reductions = state.actions.values.flatten.uniq.select { |a| a.is_a?(Reduce) }
					
					reductions.each do |r|
						(symbols - lookaheads[state.id][@lh_sides[r.id]]).each do |sym|
							state.actions[sym].delete(r)
						end
					end
					
					########################################
					# Precedence and Associativity Pruning #
					########################################
					
					state.actions.each do |symbol, actions|
						
						# We are only interested in pruning actions for
						# terminal symbols.
						next unless CFG::is_terminal?(symbol)
						
						# Skip to the next one if there is no possibility
						# of a Shift/Reduce or Reduce/Reduce conflict.
						next unless actions and actions.length > 1
						
						reduces_ok = actions.inject(true) do |m, a|
							if a.is_a?(Reduce)
								m and @rule_precs[a.id]
							else
								m
							end
						end
						
						if @token_precs[symbol] and reduces_ok
							max_prec = 0
							selected_action = nil
							
							# Grab the associativity and precedence for
							# the input token.
							tassoc, tprec = @token_precs[symbol]
							
							actions.each do |a|
								assoc, prec = a.is_a?(Shift) ? [tassoc, tprec] : @rule_precs[a.id]
								
								# If two actions have the same precedence we
								# will only replace the previous rule if:
								#  * The token is left associative and the current action is a Reduce
								#  * The Token is right associative and the current action is a Shift
								if prec > max_prec or (prec == max_prec and tassoc == (a.is_a?(Shift) ? :right : :left))
									max_prec			= prec
									selected_action	= a
									
								elsif prec == max_prec and assoc == :nonassoc
									raise ParserConstructionError, 'Non-associative token found during conflict resolution.'
									
								end
							end
							
							state.actions[symbol] = [selected_action]
						end
					end
				end
			end
			
			def right(*symbols)
				prec_level = @prec_counts[:right] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:right, prec_level]
				end
			end
			
			def rule(symbol, expression = nil, precedence = nil, &action)
				
				# Check the symbol.
				if not (symbol.is_a?(Symbol) or symbol.is_a?(String)) or (s = symbol.to_s) != s.downcase
					riase ParserConstructionError, 'Production symbols must be Strings or Symbols and be in all lowercase.'
				end
				
				symbol = symbol.to_sym
				
				@grammar.curr_lhs	= symbol
				@curr_prec		= precedence
				
				# Set this as the start symbol if there isn't one already
				# defined.
				@start_symbol ||= symbol
				
				if expression
					self.clause(expression, precedence, &action)
				else
					self.instance_exec(&action)
				end
				
				@grammar.curr_lhs	= nil
				@curr_prec		= nil
			end
			
			def start(symbol)
				if (s = symbol.to_s) != s.downcase
					raise ParserConstructionError, 'Start symbol must be a non-terminal.'
				end
				
				@start_symbol = symbol
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
					if item.is_a?(CFG::Item) and not @items.include?(item) then @items << item end
				end
				
				alias :<< :append
				
				def clean
					@items = nil
				end
				
				def close(rules)
					self.each do |item|
						if (next_symbol = item.next_symbol) and CFG::is_nonterminal?(next_symbol)
							rules[next_symbol].each { |r| self << r.to_item }
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
						raise ParserConstructionError, "Attempting to set action for token (#{symbol}) not seen in grammar definition."
					end
				end
				
				def on_any(action)
					@actions.each { |k, v| if CFG::is_terminal?(k) then v << action end }
				end
				
				def on?(symbol)
					@actions[symbol]
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
	end
end
