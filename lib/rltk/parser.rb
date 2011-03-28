# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cfg'

#######################
# Classes and Modules #
#######################

module RLTK
	
	# Used for problems with the input string.
	class ParsingError < Exception; end
	
	# Used for errors that occure during parser construction.
	class ParserConstructionError < Exception; end
	
	# Used for runtime errors that are the parsers falt.
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
				
				def parse(tokens, opts = {})
					self.class.parse(tokens, {:environment => @env}.update(opts))
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
				@states		= Array.new
				
				@prec_counts		= {:left => 0, :right => 0, :non => 0}
				@production_precs	= Array.new
				@token_precs		= Hash.new
				
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
					
					@production_precs[r.id] = r.last_terminal
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
			
			def build_finalize_opts(opts)
				opts[:explain] = self.get_io(opts[:explain])
				
				{
					:explain		=> false,
					:lookahead	=> true,
					:precedence	=> true
				}.update(opts)
			end
			
			def build_parse_opts(opts)
				opts[:parse_tree]	= self.get_io(opts[:parse_tree])
				opts[:verbose]		= self.get_io(opts[:verbose])
				
				{
					:accept		=> :first,
					:env			=> Environment.new,
					:parse_tree	=> false,
					:verbose		=> false
				}.update(opts)
			end
			
			def check_sanity
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
			
			def check_reachability(start, dest, symbols)
				path_exists	= true
				cur_state		= start
				
				symbols.each do |sym|
					
					actions = @states[cur_state.id].on?(sym)
					actions = actions.select { |a| a.is_a?(Shift) } if CFG::is_terminal?(sym)
					
					if actions.empty?
						path_exists = false
						break
					end
					
					cur_state = @states[actions.first.id]
				end
				
				path_exists and cur_state.id == dest.id
			end
			
			def clause(expression, precedence = nil, &action)
				# Use the curr_prec only if it isn't overridden for this
				# clause.
				precedence ||= @curr_prec
				
				production = @grammar.clause(expression)
				
				# Check to make sure the action's arity matches the number
				# of symbols on the right-hand side.
				if action.arity != production.rhs.length
					raise ParserConstructionError, 'Incorrect number of arguments to action.  Action arity must match the number of ' +
						'terminals and non-terminals in the clause.'
				end
				
				# Add the action to our proc list.
				@procs[production.id] = action

				# If no precedence is specified use the precedence of the
				# last terminal in the production.
				@production_precs[production.id] = precedence || production.last_terminal
			end
			
			def clean
				# We've told the developer about conflicts by now.
				@conflicts = nil
				
				# Drop the grammar.
				@grammar = nil
				
				# Drop the items from each of the states.
				@states.each { |state| state.clean }
			end
			
			def explain(file)
				if @grammar and not @states.empty?
					file.puts("###############")
					file.puts("# Productions #")
					file.puts("###############")
					file.puts
					
					# Print the productions.
					@grammar.productions.each do |sym, productions|
						productions.each do |production|
							file.print("\Production #{production.id}: #{production.to_s}")
							
							if (prec = @production_precs[production.id])
								file.print(" : (#{prec.first} , #{prec.last})")
							end
							
							file.puts
						end
						
						file.puts
					end
					
					file.puts("##########")
					file.puts("# Tokens #")
					file.puts("##########")
					file.puts
					
					@grammar.terms.sort {|a,b| a.to_s <=> b.to_s }.each do |term|
						file.print("\t#{term}")
						
						if (prec = @token_precs[term])
							file.print(" : (#{prec.first}, #{prec.last})")
						end
						
						file.puts
					end
					
					file.puts
					
					file.puts("#####################")
					file.puts("# Table Information #")
					file.puts("#####################")
					file.puts
					
					file.puts("\tStart symbol: #{@grammar.start_symbol}")
					file.puts
					
					file.puts("\tTotal number of states: #{@states.length}")
					file.puts
					
					file.puts("\tTotal conflicts: #{@conflicts.values.flatten(1).length}")
					file.puts
					
					@conflicts.each do |state_id, conflicts|
						file.puts("\tState #{state_id} has #{conflicts.length} conflict(s)")
					end
					
					file.puts if not @conflicts.empty?
					
					# Print the parse table.
					file.puts("###############")
					file.puts("# Parse Table #")
					file.puts("###############")
					file.puts
					
					@states.each do |state|
						file.puts("State #{state.id}:")
						file.puts
						
						file.puts("\t# ITEMS #")
						max = state.items.inject(0) do |max, item|
							if item.lhs.to_s.length > max then item.lhs.to_s.length else max end
						end
						
						state.each do |item|
							file.puts("\t#{item.to_s(max)}")
						end
						
						file.puts
						file.puts("\t# ACTIONS #")
						
						state.actions.keys.sort {|a,b| a.to_s <=> b.to_s}.each do |sym|
							state.actions[sym].each do |action|
								file.puts("\tOn #{sym} #{action}")
							end
						end
						
						file.puts
						file.puts("\t# CONFLICTS #")
						
						if @conflicts[state.id].length == 0
							file.puts("\tNone\n\n")
						else
							@conflicts[state.id].each do |conflict|
								type, sym = conflict
								
								file.print("\t#{if type == :SR then "Shift/Reduce" else "Reduce/Reduce" end} conflict")
								
								file.puts(" on #{sym}")
							end
							
							file.puts
						end
					end
					
					# Close any IO objects that aren't $stdout.
					file.close if file.is_a?(IO) and file != $stdout
				else
					raise ParserConstructionError, 'Parser.explain called outside of finalize.'
				end
			end
			
			def finalize(opts = {})
				
				opts = self.build_finalize_opts(opts)
				
				# Grab all of the symbols that comprise the grammar (besides
				# the start symbol).
				@symbols = @grammar.symbols
				
				# Add our starting state to the state list.
				start_production	= @grammar.production(:start, @grammar.start_symbol.to_s).first
				start_state		= State.new(@symbols, [start_production.to_item])
				
				start_state.close(@grammar.productions)
				
				self.add_state(start_state)
				
				# Translate the precedence of productions from tokens to
				# (associativity, precedence) pairs.
				
				@production_precs.each_with_index do |prec, id|
					@production_precs[id] = @token_precs[prec]
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
						
						tstate.close(@grammar.productions)
						
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
				
				# Build the production.id -> production.lhs map.
				@grammar.productions(:id).to_a.inject(@lh_sides) do |h, pair|
					id, production = pair
					
					h[id] = production.lhs
					
					h
				end
				
				# Prune the parsing table for unnecessary reduce actions.
				self.prune(opts[:lookahead], opts[:precedence])
				
				# Check the parser for inconsistencies.
				self.check_sanity
				
				# Print the table if requested.
				self.explain(opts[:explain]) if opts[:explain]
				
				# Clean the resources we are keeping.
				self.clean
			end
			
			def get_io(o)
				if o.is_a?(TrueClass)
					$stdout
				elsif o.is_a?(String)
					File.open(o, 'w')
				elsif o.is_a?(IO)
					o
				else
					false
				end
			end
			
			def grammar_prime
				if not @grammar_prime
					@grammar_prime = CFG.new
					
					@states.each do |state|
						state.each do |item|
							lhs = "#{state.id}_#{item.next_symbol}".to_sym
							
							next unless CFG::is_nonterminal?(item.next_symbol) and not @grammar_prime.productions.keys.include?(lhs)
							
							@grammar.productions[item.next_symbol].each do |production|
								rhs = ""
								
								cstate = state
								
								production.rhs.each do |symbol|
									rhs += "#{cstate.id}_#{symbol} "
									
									cstate = @states[cstate.on?(symbol).first.id]
								end
								
								@grammar_prime.production(lhs, rhs)
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
			
			def parse(tokens, opts = {})
				opts	= self.build_parse_opts(opts)
				v	= opts[:verbose]
				
				if opts[:verbose]
					v.puts("Input tokens:")
					v.puts(tokens.map { |t| t.type }.inspect)
					v.puts
				end
				
				# Stack IDs to keep track of them during parsing.
				stack_id = 0
				
				# Our various list of stacks.
				accepted		= []
				moving_on		= []
				processing	= [ParseStack.new(stack_id += 1)]
				
				# Iterate over the tokens.  We don't procede to the
				# next token until every stack is done with the
				# current one.
				tokens.each do |token|
					
					#~puts "Processing:"
					#~pp processing
					#~
					#~puts "Moving on:"
					#~pp moving_on
					
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
					
					v.puts("Current token: #{token.type}#{if token.value then "(#{token.value})" end}") if v
					
					# Iterate over the stacks until each one is done.
					until processing.empty?
						# Grab the current stack.
						stack = processing.shift
						
						# Get the available actions for this stack.
						actions = @states[stack.state].on?(token.type)
						
						# Drop this stack if there are no actions.
						if actions.empty?
							v.puts("No more actions for stack #{stack.id}.  Dropping stack.") if v
							
							next
						end
						
						# Make (stack, action) pairs, duplicating the
						# stack as necessary.
						pairs = [[stack, actions.pop]] + actions.map {|action| [stack.branch(stack_id += 1), action] }
						
						pairs.each do |stack, action|
							if v
								v.puts
								v.puts('Current stack:')
								v.puts("\tID: #{stack.id}")
								v.puts("\tState stack:\t#{stack.state_stack.inspect}")
								v.puts("\tOutput Stack:\t#{stack.output_stack.inspect}")
								v.puts
								v.puts("Action taken: #{action.to_s}")
							end
							
							if action.is_a?(Accept)
								if opts[:accept] == :all
									accepted << stack
								else
									v.puts('Accepting input.') if v
									opts[:parse_tree].puts(stack.tree) if opts[:parse_tree]
									
									return stack.result
								end
							
							elsif action.is_a?(Reduce)
								# Get the production associated with this reduction.
								if not (production_proc = @procs[action.id])
									raise InternalParserError, "No production #{action.id} found."
								end
								
								result = v.instance_exec(*stack.pop(production_proc.arity), &production_proc)
								
								if (goto = @states[stack.state].on?(@lh_sides[action.id]).first)
									
									v.puts("Going to state #{goto.id}.\n") if v
									
									stack.push(goto.id, result, @lh_sides[action.id])
								else
									raise InternalParserError, "No GoTo action found in state #{nstack.state} " +
										"after reducing by production #{action.id}"
								end
								
								# This stack is NOT ready for the next
								# token.
								processing << stack
								
							elsif action.is_a?(Shift)
								stack.push(action.id, token.value, token.type)
								
								# This stack is ready for the next
								# token.
								moving_on << stack
							end
						end
					end
					
					v.puts("\n\n") if v
					
					processing	= moving_on
					moving_on		= []
				end
				
				# If we have reached this point we accept all derivations.
				v.puts("Accepting input with #{accepted.length} derivation(s).") if v
				
				accepted.each do |stack|
					opts[:parse_tree].puts(stack.tree) if opts[:parse_tree]
				end
				
				return accepted.map { |stack| stack.result }
			end
			
			def production(symbol, expression = nil, precedence = nil, &action)
				
				# Check the symbol.
				if not (symbol.is_a?(Symbol) or symbol.is_a?(String)) or not CFG::is_nonterminal?(symbol)
					riase ParserConstructionError, 'Production symbols must be Strings or Symbols and be in all lowercase.'
				end
				
				@grammar.curr_lhs	= symbol.to_sym
				@curr_prec		= precedence
				
				if expression
					self.clause(expression, precedence, &action)
				else
					self.instance_exec(&action)
				end
				
				@grammar.curr_lhs	= nil
				@curr_prec		= nil
			end
			
			def prune(do_lookahead, do_precedence)
				terms = @grammar.terms
				
				# If both options are false there is no pruning to do.
				return if not (do_lookahead or do_precedence)
				
				@states.each do |state0|
					
					#####################
					# Lookahead Pruning #
					#####################
					
					if do_lookahead
						# Find all of the reductions in this state.
						reductions = state0.actions.values.flatten.uniq.select { |a| a.is_a?(Reduce) }
						
						reductions.each do |reduction|
							production = @grammar.productions(:id)[reduction.id]
							
							lookahead = []
							
							# Build the lookahead set.
							@states.each do |state1|
								if self.check_reachability(state1, state0, production.rhs)
									lookahead += self.grammar_prime.follow_set("#{state1.id}_#{production.lhs}".to_sym)
								end
							end
							
							# Translate the G' follow symbols into G lookahead
							# symbols.
							lookahead = lookahead.map { |sym| sym.to_s.split('_').last.to_sym }
							
							# Remove the Reduce action from all terminal
							# symbols that don't appear in the lookahead set.
							(terms - lookahead).each do |sym|
								state0.actions[sym].delete(reduction)
							end
						end
					end
					
					########################################
					# Precedence and Associativity Pruning #
					########################################
					
					if do_precedence
						state0.actions.each do |symbol, actions|
							
							# We are only interested in pruning actions
							# for terminal symbols.
							next unless CFG::is_terminal?(symbol)
							
							# Skip to the next one if there is no 
							# possibility of a Shift/Reduce or
							# Reduce/Reduce conflict.
							next unless actions and actions.length > 1
							
							reduces_ok = actions.inject(true) do |m, a|
								if a.is_a?(Reduce)
									m and @production_precs[a.id]
								else
									m
								end
							end
							
							if @token_precs[symbol] and reduces_ok
								max_prec = 0
								selected_action = nil
								
								# Grab the associativity and precedence
								# for the input token.
								tassoc, tprec = @token_precs[symbol]
								
								actions.each do |a|
									assoc, prec = a.is_a?(Shift) ? [tassoc, tprec] : @production_precs[a.id]
									
									# If two actions have the same precedence we
									# will only replace the previous production if:
									#  * The token is left associative and the current action is a Reduce
									#  * The Token is right associative and the current action is a Shift
									if prec > max_prec or (prec == max_prec and tassoc == (a.is_a?(Shift) ? :right : :left))
										max_prec			= prec
										selected_action	= a
										
									elsif prec == max_prec and assoc == :nonassoc
										raise ParserConstructionError, 'Non-associative token found during conflict resolution.'
										
									end
								end
								
								state0.actions[symbol] = [selected_action]
							end
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
			
			def start(symbol)
				@grammar.start symbol
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
				
				def close(productions)
					self.each do |item|
						if (next_symbol = item.next_symbol) and CFG::is_nonterminal?(next_symbol)
							productions[next_symbol].each { |p| self << p.to_item }
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
					@actions[symbol].clone
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
					"Reduce by Production #{self.id}"
				end
			end
			
			class Shift < Action
				def to_s
					"Shift to State #{self.id}"
				end
			end
		end
		
		class ParseStack
			attr_reader :id
			attr_reader :output_stack
			attr_reader :state_stack
			
			def initialize(id, ostack = [], sstack = [0], nstack = [], connections = [], labels = [])
				@id = id
				
				@node_stack	= nstack
				@output_stack	= ostack
				@state_stack	= sstack
				
				@connections	= connections
				@labels		= labels
			end
			
			def branch(new_id)
				ParseStack.new(new_id, Array.new(@output_stack), Array.new(@state_stack),
					Array.new(@node_stack), Array.new(@connections), Array.new(@labels))
			end
			
			def push(state, o, node0)
				@state_stack	<< state
				@output_stack	<< o
				@node_stack	<< @labels.length
				@labels		<< node0
				
				if CFG::is_nonterminal?(node0)
					@cbuffer.each do |node1|
						@connections << [@labels.length - 1, node1]
					end
				end
			end
			
			def pop(n = 1)
				@state_stack.pop(n)
				
				# Pop the node stack so that the proper edges can be added
				# when the production's left-hand side non-terminal is
				# pushed onto the stack.
				@cbuffer = @node_stack.pop(n)
				
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
			
			def tree
				tree  = "digraph tree#{@id} {\n"
				
				@labels.each_with_index do |label, i|
					tree += "\tnode#{i} [label=\"#{label}\""
					
					if CFG::is_terminal?(label)
						tree += " shape=box"
					end
					
					tree += "];\n"
				end
				
				tree += "\n"
				
				@connections.each do |from, to|
					tree += "\tnode#{from} -> node#{to};\n"
				end
				
				tree += "}"
			end
		end
	end
end
