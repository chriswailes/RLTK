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

module RLTK # :nodoc:
	
	# A BadToken error indicates that a token was observed in the input stream
	# that wasn't used in the grammar's definition.
	class BadToken < StandardError
		# @return [String] String representation of the error.
		def to_s
			'Unexpected token.  Token not present in grammar definition.'
		end
	end
	
	# A NotInLanguage error is raised whenever there is no valid parse tree
	# for a given token stream.  In other words, the input string is not in the
	# defined language.
	class NotInLanguage < StandardError
		# @return [String] String representation of the error.
		def to_s
			'String not in language.'
		end
	end
	
	# An error of this type is raised when the parser encountered a error that
	# was handled by an error production.
	class HandledError < StandardError
		
		# The errors as reported by the parser.
		# 
		# @return [Array<Object>]
		attr_reader :errors
		
		# The result that would have been returned by the call to *parse*.
		attr_reader :result
		
		# Instantiate a new HandledError object with *errors*.
		#
		# @param [Array<Object>]	errors Errors added to the parsing environment by calls to {Parser::Environment#error}.
		# @param [Object]		result Object resulting from parsing Tokens before the error occurred.
		def initialize(errors, result)
			@errors = errors
			@result = result
		end
	end
	
	# Used for exceptions that occure during parser construction.
	class ParserConstructionException < Exception; end
	
	# Used for runtime exceptions that are the parsers fault.  These should
	# never be observed in the wild.
	class InternalParserException < Exception; end
	
	# The Parser class may be sub-classed to produce new parsers.  These
	# parsers have a lot of features, and are described in the main
	# documentation.
	class Parser
		# @return [Environment] Environment used by the instantiated parser.
		attr_reader :env
		
		#################
		# Class Methods #
		#################
		
		class << self
			# Installs instance class varialbes into a class.
			#
			# @return [void]
			def install_icvars
				@curr_lhs		= nil
				@curr_prec	= nil
				
				@conflicts	= Hash.new {|h, k| h[k] = Array.new}
				@grammar		= CFG.new
				
				@lh_sides		= Hash.new
				@procs		= Array.new
				@states		= Array.new
				
				# Variables for dealing with precedence.
				@prec_counts		= {:left => 0, :right => 0, :non => 0}
				@production_precs	= Array.new
				@token_precs		= Hash.new
				
				# Set the default argument handling policy.
				@args = :splat
				
				@grammar.callback do |p, type, num|
					@procs[p.id] =
					[
						case type
						when :*
							case num
							when :first then	Proc.new { ||           [] }
							else				Proc.new { |os, o| os << o }
							end
							
						when :+
							case num
							when :first then	Proc.new { |o|         [o] }
							else				Proc.new { |os, o| os << o }
							end
							
						when :'?'
							case num
							when :first then	Proc.new { ||  nil }
							else				Proc.new { |o|   o }
							end
							
						when :elp
							case num
							when :first then	Proc.new { ||         [] }
							else				Proc.new { |prime| prime }
							end
							
						when :nelp
							case num
							when :first	then	Proc.new { |el|                                         [el] }
							when :second	then	Proc.new { |els, _, el|                           els + [el] }
							else				Proc.new { |*el| if el.length == 1 then el.first else el end }
							end
						end,
						p.rhs.length
					]
					
					@production_precs[p.id] = p.last_terminal
				end
			end
			
			# Called when the Lexer class is sub-classed, it installes
			# necessary instance class variables.
			#
			# @return [void]
			def inherited(klass)
				klass.install_icvars
			end
			
			# If *state* (or its equivalent) is not in the state list it is
			# added and it's ID is returned.  If there is already a state
			# with the same items as *state* in the state list its ID is
			# returned and *state* is discarded.
			#
			# @param [State] state State to add to the parser.
			#
			# @return [Integer] The ID of the state.
			def add_state(state)
				if (id = @states.index(state))
					id
				else
					state.id = @states.length
					
					@states << state
					
					@states.length - 1
				end
			end
			
			# Calling this method will cause the parser to pass right-hand
			# side values as arrays instead of splats.  This method must be
			# called before ANY calls to Parser.production.
			#
			# @return [void]
			def array_args
				if @grammar.productions.length == 0
					@args = :array
					
					@grammar.callback do |p, type, num|
						@procs[p.id] =
						[
							case type
							when :*
								case num
								when :first then	Proc.new { |v|           [] }
								else				Proc.new { |v| v[0] << v[1] }
								end
							
							when :+
								case num
								when :first then	Proc.new { |v|       [v[0]] }
								else				Proc.new { |v| v[0] << v[1] }
								end
							
							when :'?'
								case num
								when :first then	Proc.new { |v|  nil }
								else				Proc.new { |v| v[0] }
								end
							
							when :elp
								case num
								when :first then	Proc.new { |v|   [] }
								else				Proc.new { |v| v[0] }
								end
							
							when :nelp
								case num
								when :first	then	Proc.new { |v|                                        v }
								when :second	then	Proc.new { |v|                            v[0] + [v[2]] }
								else				Proc.new { |v| if v.length == 1 then v.first else v end }
								end
							end,
							p.rhs.length
						]
						
						@production_precs[p.id] = p.last_terminal
					end
				end
			end
			
			# Build a hash with the default options for Parser.finalize
			# and then update it with the values from *opts*.
			#
			# @param [Hash{Symbol => Object}] opts Hash containing options for finalize.
			#
			# @return [Hash{Symbol => Object}]
			def build_finalize_opts(opts)
				opts[:explain]	= self.get_io(opts[:explain])
				
				{
					:explain		=> false,
					:lookahead	=> true,
					:precedence	=> true,
					:use			=> false
				}.update(opts)
			end
			private :build_finalize_opts
			
			# Build a hash with the default options for Parser.parse and
			# then update it with the values from *opts*.
			#
			# @param [Hash{Symbol => Object}] opts Hash containing options for parse.
			#
			# @return [Hash{Symbol => Object}]
			def build_parse_opts(opts)
				opts[:parse_tree]	= self.get_io(opts[:parse_tree])
				opts[:verbose]		= self.get_io(opts[:verbose])
				
				{
					:accept		=> :first,
					:env			=> self::Environment.new,
					:parse_tree	=> false,
					:verbose		=> false
				}.update(opts)
			end
			private :build_parse_opts
			
			# This method is used to (surprise) check the sanity of the
			# constructed parser.  It checks to make sure all non-terminals
			# used in the grammar definition appear on the left-hand side of
			# one or more productions, and that none of the parser's states
			# have invalid actions.  If a problem is encountered a
			# ParserConstructionException is raised.
			#
			# @return [void]
			def check_sanity
				# Check to make sure all non-terminals appear on the
				# left-hand side of some production.
				@grammar.nonterms.each do |sym|
					if not @lh_sides.values.include?(sym)
						raise ParserConstructionException, "Non-terminal #{sym} does not appear on the left-hand side of any production."
					end
				end
				
				# Check the actions in each state.
				@states.each do |state|
					state.actions.each do |sym, actions|
						if CFG::is_terminal?(sym)
							# Here we check actions for terminals.
							actions.each do |action|
								if action.is_a?(Accept)
									if sym != :EOS
										raise ParserConstructionException, "Accept action found for terminal #{sym} in state #{state.id}."
									end
										
								elsif not (action.is_a?(GoTo) or action.is_a?(Reduce) or action.is_a?(Shift))
									raise ParserConstructionException, "Object of type #{action.class} found in actions for terminal " +
										"#{sym} in state #{state.id}."
									
								end
							end
							
							if (conflict = state.conflict_on?(sym))
								self.inform_conflict(state.id, conflict, sym)
							end
						else
							# Here we check actions for non-terminals.
							if actions.length > 1
								raise ParserConstructionException, "State #{state.id} has multiple GoTo actions for non-terminal #{sym}."
								
							elsif actions.length == 1 and not actions.first.is_a?(GoTo)
								raise ParserConstructionException, "State #{state.id} has non-GoTo action for non-terminal #{sym}."
								
							end
						end
					end
				end
			end
			
			# This method checks to see if the parser would be in parse state
			# *dest* after starting in state *start* and reading *symbols*.
			#
			# @param [Symbol]		start	Symbol representing a CFG production.
			# @param [Symbol]		dest		Symbol representing a CFG production.
			# @param [Array<Symbol>]	symbols	Grammar symbols.
			#
			# @return [Boolean] If the destination symbol is reachable from the start symbol after reading *symbols*.
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
					
					# There can only be one Shift action for terminals and
					# one GoTo action for non-terminals, so we know the
					# first action is the only one in the list.
					cur_state = @states[actions.first.id]
				end
				
				path_exists and cur_state.id == dest.id
			end
			
			# Declares a new clause inside of a production.  The right-hand
			# side is specified by *expression* and the precedence of this
			# production can be changed by setting the *precedence* argument
			# to some terminal symbol.
			#
			# @param [String]	expression	Right-hand side of a production.
			# @param [Symbol]	precedence	Symbol representing the precedence of this production.
			# @param [Proc]	action		Action to be taken when the production is reduced.
			#
			# @return [void]
			def clause(expression, precedence = nil, &action)
				# Use the curr_prec only if it isn't overridden for this
				# clause.
				precedence ||= @curr_prec
				
				production = @grammar.clause(expression)
				
				# Check to make sure the action's arity matches the number
				# of symbols on the right-hand side.
				if @args == :splat and action.arity != production.rhs.length
					raise ParserConstructionException, 'Incorrect number of arguments to action.  Action arity must match the number of ' +
						'terminals and non-terminals in the clause.'
				end
				
				# Add the action to our proc list.
				@procs[production.id] = [action, production.rhs.length]
				
				# If no precedence is specified use the precedence of the
				# last terminal in the production.
				@production_precs[production.id] = precedence || production.last_terminal
			end
			alias :c :clause
			
			# Removes resources that were needed to generate the parser but
			# aren't needed when actually parsing input.
			#
			# @return [void]
			def clean
				# We've told the developer about conflicts by now.
				@conflicts = nil
				
				# Drop the grammar and the grammar'.
				@grammar		= nil
				@grammar_prime	= nil
				
				# Drop precedence and bookkeeping information.
				@cur_lhs	= nil
				@cur_prec	= nil
				
				@prec_counts		= nil
				@production_precs	= nil
				@token_precs		= nil
				
				# Drop the items from each of the states.
				@states.each { |state| state.clean }
			end
			
			# Adds productions and actions for parsing empty lists.
			#
			# @see CFG#empty_list_production
			def empty_list_production(symbol, list_elements, separator)
				@grammar.empty_list(symbol, list_elements, separator)
			end
			alias :empty_list :empty_list_production 
			
			# This function will print a description of the parser to the
			# provided IO object.
			#
			# @param [IO] io Input/Output object used for printing the parser's explanation.
			#
			# @return [void]
			def explain(io)
				if @grammar and not @states.empty?
					io.puts('###############')
					io.puts('# Productions #')
					io.puts('###############')
					io.puts
					
					# Print the productions.
					@grammar.productions.each do |sym, productions|
						productions.each do |production|
							io.print("\tProduction #{production.id}: #{production.to_s}")
							
							if (prec = @production_precs[production.id])
								io.print(" : (#{prec.first} , #{prec.last})")
							end
							
							io.puts
						end
						
						io.puts
					end
					
					io.puts('##########')
					io.puts('# Tokens #')
					io.puts('##########')
					io.puts
					
					@grammar.terms.sort {|a,b| a.to_s <=> b.to_s }.each do |term|
						io.print("\t#{term}")
						
						if (prec = @token_precs[term])
							io.print(" : (#{prec.first}, #{prec.last})")
						end
						
						io.puts
					end
					
					io.puts
					
					io.puts('#####################')
					io.puts('# Table Information #')
					io.puts('#####################')
					io.puts
					
					io.puts("\tStart symbol: #{@grammar.start_symbol}")
					io.puts
					
					io.puts("\tTotal number of states: #{@states.length}")
					io.puts
					
					io.puts("\tTotal conflicts: #{@conflicts.values.flatten(1).length}")
					io.puts
					
					@conflicts.each do |state_id, conflicts|
						io.puts("\tState #{state_id} has #{conflicts.length} conflict(s)")
					end
					
					io.puts if not @conflicts.empty?
					
					# Print the parse table.
					io.puts('###############')
					io.puts('# Parse Table #')
					io.puts('###############')
					io.puts
					
					@states.each do |state|
						io.puts("State #{state.id}:")
						io.puts
						
						io.puts("\t# ITEMS #")
						max = state.items.inject(0) do |max, item|
							if item.lhs.to_s.length > max then item.lhs.to_s.length else max end
						end
						
						state.each do |item|
							io.puts("\t#{item.to_s(max)}")
						end
						
						io.puts
						io.puts("\t# ACTIONS #")
						
						state.actions.keys.sort {|a,b| a.to_s <=> b.to_s}.each do |sym|
							state.actions[sym].each do |action|
								io.puts("\tOn #{sym} #{action}")
							end
						end
						
						io.puts
						io.puts("\t# CONFLICTS #")
						
						if @conflicts[state.id].length == 0
							io.puts("\tNone\n\n")
						else
							@conflicts[state.id].each do |conflict|
								type, sym = conflict
								
								io.print("\t#{if type == :SR then "Shift/Reduce" else "Reduce/Reduce" end} conflict")
								
								io.puts(" on #{sym}")
							end
							
							io.puts
						end
					end
					
					# Close any IO objects that aren't $stdout.
					io.close if io.is_a?(IO) and io != $stdout
				else
					raise ParserConstructionException, 'Parser.explain called outside of finalize.'
				end
			end
			
			# This method will finalize the parser causing the construction
			# of states and their actions, and the resolution of conflicts
			# using lookahead and precedence information.
			# 
			# The *opts* hash may contain the following options, which are
			# described in more detail in the main documentation:
			# 
			# * :explain - To explain the parser or not.
			# * :lookahead - To use lookahead info for conflict resolution.
			# * :precedence - To use precedence info for conflict resolution.
			# * :use - A file name or object that is used to load/save the parser.
			# 
			# No calls to {Parser.production} may appear after the call to
			# Parser.finalize.
			#
			# @param [Hash{Symbol => Object}] opts Options describing how to finalize the parser.
			#
			# @return [void]
			def finalize(opts = {})
				
				# Get the full options hash.
				opts = build_finalize_opts(opts)
				
				# Get the name of the file in which the parser is defined.
				#
				# FIXME: See why this is failing for the simple ListParser example.
				def_file = caller()[2].split(':')[0] if opts[:use]
				
				# Check to make sure we can load the necessary information
				# from the specified object.
				if opts[:use] and (
					(opts[:use].is_a?(String) and File.exists?(opts[:use]) and File.mtime(opts[:use]) > File.mtime(def_file)) or
					(opts[:use].is_a?(File) and opts[:use].mtime > File.mtime(def_file))
					)
					
					file = self.get_io(opts[:use], 'r')
					
					# Un-marshal our saved data structures.
					file.flock(File::LOCK_SH)
					@lh_sides, @states, @symbols = Marshal.load(file)
					file.flock(File::LOCK_UN)
					
					# Close the file if we opened it.
					file.close if opts[:use].is_a?(String)
					
					# Remove any un-needed data and return.
					return self.clean
				end
				
				# Grab all of the symbols that comprise the grammar (besides
				# the start symbol).
				@symbols = @grammar.symbols << :ERROR
				
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
						if item.at_end?
							if item.lhs == :start
								state.on(:EOS, Accept.new)
							else
								state.add_reduction(item.id)
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
				
				# Remove any data that is no longer needed.
				self.clean
				
				# Store the parser's final data structures if requested.
				if opts[:use]
					io = self.get_io(opts[:use])
					
					io.flock(File::LOCK_EX) if io.is_a?(File)
					Marshal.dump([@lh_sides, @states, @symbols], io)
					io.flock(File::LOCK_UN) if io.is_a?(File)
					
					# Close the IO object if we opened it.
					io.close if opts[:use].is_a?(String)
				end
			end
			
			# Converts an object into an IO object as appropriate.
			#
			# @param [Object] o		Object to be converted into an IO object.
			# @param [String] mode	String representing the mode to open the IO object in.
			#
			# @return [IO, false] The IO object or false if a conversion wasn't possible.
			def get_io(o, mode = 'w')
				if o.is_a?(TrueClass)
					$stdout
				elsif o.is_a?(String)
					File.open(o, mode)
				elsif o.is_a?(IO)
					o
				else
					false
				end
			end
			
			# @return [CFG] The grammar that can be parsed by this Parser.
			def grammar
				@grammar.clone
			end
			
			# This method generates and memoizes the G' grammar used to
			# calculate the LALR(1) lookahead sets.  Information about this
			# grammar and its use can be found in the following paper:
			# 
			# Simple Computation of LALR(1) Lookahed Sets
			# Manuel E. Bermudez and George Logothetis
			# Information Processing Letters 31 - 1989
			#
			# @return [CFG]
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
			
			# Inform the parser core that a conflict has been detected.
			#
			# @param [Integer]	state_id	ID of the state where the conflict was encountered.
			# @param [:RR, :SR]	type		Reduce/Reduce or Shift/Reduce conflict.
			# @param [Symbol]	sym		Symbol that caused the conflict.
			#
			# @return [void]
			def inform_conflict(state_id, type, sym)
				@conflicts[state_id] << [type, sym]
			end
			
			# This method is used to specify that the symbols in *symbols*
			# are left-associative.  Subsequent calls to this method will
			# give their arguments higher precedence.
			#
			# @param [Array<Symbol>] symbols Symbols that are left associative.
			#
			# @return [void]
			def left(*symbols)
				prec_level = @prec_counts[:left] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:left, prec_level]
				end
			end
			
			# This method is used to specify that the symbols in *symbols*
			# are non-associative.
			#
			# @param [Array<Symbol>] symbols Symbols that are non-associative.
			#
			# @return [void]
			def nonassoc(*symbols)
				prec_level = @prec_counts[:non] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:non, prec_level]
				end
			end
			
			# Adds productions and actions for parsing nonempty lists.
			#
			# @see CFG#nonempty_list_production
			def nonempty_list_production(symbol, list_elements, separator)
				@grammar.nonempty_list(symbol, list_elements, separator)
			end
			alias :nonempty_list :nonempty_list_production 
			
			# This function is where actual parsing takes place.  The
			# _tokens_ argument must be an array of Token objects, the last
			# of which has type EOS.  By default this method will return the
			# value computed by the first successful parse tree found.  It is
			# possible to adjust this behavior using the _opts_ hash as
			# follows:
			# 
			# * :accept - Either :first or :all.
			# * :env - The environment in which to evaluate the production actions.
			# * :parse_tree - To print parse trees in the DOT language or not.
			# * :verbose - To be verbose or not.
			# 
			# Additional information for these options can be found in the
			# main documentation.
			#
			# @param [Array<Token>] tokens Tokens to be parsed.
			#
			# @return [Object, Array<Object>] Result or results of parsing the given tokens.
			def parse(tokens, opts = {})
				# Get the full options hash.
				opts	= build_parse_opts(opts)
				v	= opts[:verbose]
				
				if opts[:verbose]
					v.puts("Input tokens:")
					v.puts(tokens.map { |t| t.type }.inspect)
					v.puts
				end
				
				# Stack IDs to keep track of them during parsing.
				stack_id = 0
				
				# Error mode indicators.
				error_mode		= false
				reduction_guard	= false
				
				# Our various list of stacks.
				accepted		= []
				moving_on		= []
				processing	= [ParseStack.new(stack_id += 1)]
				
				# Iterate over the tokens.  We don't procede to the
				# next token until every stack is done with the
				# current one.
				tokens.each do |token|
					# Check to make sure this token was seen in the
					# grammar definition.
					raise BadToken if not @symbols.include?(token.type)
					
					v.puts("Current token: #{token.type}#{if token.value then "(#{token.value})" end}") if v
					
					# Iterate over the stacks until each one is done.
					while (stack = processing.shift)
						# Get the available actions for this stack.
						actions = @states[stack.state].on?(token.type)
						
						if actions.empty?
							# If we are already in error mode and there
							# are no actions we skip this token.
							if error_mode
								moving_on << stack
								next
							end
							
							# We would be dropping the last stack so we
							# are going to go into error mode.
							if accepted.empty? and moving_on.empty? and processing.empty?
								# Try and find a valid error state.
								while stack.state
									if (actions = @states[stack.state].on?(:ERROR)).empty?
										# This state doesn't have an
										# error production. Moving on.
										stack.pop
									else
										# Enter the found error state.
										stack.push(actions.first.id, nil, :ERROR, token.position)
										
										break
									end
								end
								
								if stack.state
									# We found a valid error state.
									error_mode = reduction_guard = true
									opts[:env].he = true
									processing << stack
									
									v.puts('Invalid input encountered.  Entering error handling mode.') if v
								else
									# No valid error states could be
									# found.  Time to print a message
									# and leave.
									
									v.puts("No more actions for stack #{stack.id}.  Dropping stack.") if v
								end
							else
								v.puts("No more actions for stack #{stack.id}.  Dropping stack.") if v
							end
							
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
									
									if opts[:env].he
										raise HandledError.new(opts[:env].errors, stack.result)
									else
										return stack.result
									end
								end
							
							elsif action.is_a?(Reduce)
								# Get the production associated with this reduction.
								production_proc, pop_size = @procs[action.id]
								
								if not production_proc
									raise InternalParserException, "No production #{action.id} found."
								end
								
								args, positions = stack.pop(pop_size)
								opts[:env].set_positions(positions)
								
								result =
								if @args == :array
									opts[:env].instance_exec(args, &production_proc)
								else
									opts[:env].instance_exec(*args, &production_proc)
								end
								
								if (goto = @states[stack.state].on?(@lh_sides[action.id]).first)
									
									v.puts("Going to state #{goto.id}.\n") if v
									
									pos0 = nil
									
									if args.empty?
										# Empty productions need to be
										# handled specially.
										pos0 = stack.position
										
										pos0.stream_offset	+= pos0.length + 1
										pos0.line_offset	+= pos0.length + 1
										
										pos0.length = 0
									else
										pos0 = opts[:env].pos( 0)
										pos1 = opts[:env].pos(-1)
										
										pos0.length = (pos1.stream_offset + pos1.length) - pos0.stream_offset
									end
									
									stack.push(goto.id, result, @lh_sides[action.id], pos0)
								else
									raise InternalParserException, "No GoTo action found in state #{stack.state} " +
										"after reducing by production #{action.id}"
								end
								
								# This stack is NOT ready for the next
								# token.
								processing << stack
								
								# Exit error mode if necessary.
								error_mode = false if error_mode and not reduction_guard
								
							elsif action.is_a?(Shift)
								stack.push(action.id, token.value, token.type, token.position)
								
								# This stack is ready for the next
								# token.
								moving_on << stack
								
								# Exit error mode.
								error_mode = false
							end
						end
					end
					
					v.puts("\n\n") if v
					
					processing	= moving_on
					moving_on		= []
					
					# If we don't have any active stacks at this point the
					# string isn't in the language.
					if opts[:accept] == :first and processing.length == 0
						v.close if v and v != $stdout
						raise NotInLanguage
					end
					
					reduction_guard = false
				end
				
				# If we have reached this point we are accepting all parse
				# trees.
				if v
					v.puts("Accepting input with #{accepted.length} derivation(s).")
					
					v.close if v != $stdout
				end
				
				accepted.each do |stack|
					opts[:parse_tree].puts(stack.tree)
				end if opts[:parse_tree]
				
				results = accepted.map { |stack| stack.result }
				
				if opts[:env].he
					raise HandledError.new(opts[:env].errors, results)
				else
					return results
				end
			end
			
			# Adds a new production to the parser with a left-hand value of
			# *symbol*.  If *expression* is specified it is taken as the
			# right-hand side of the production and *action* is associated
			# with the production.  If *expression* is nil then *action* is
			# evaluated and expected to make one or more calls to
			# Parser.clause.  A precedence can be associate with this
			# production by setting *precedence* to a terminal symbol.
			#
			# @param [Symbol]		symbol		Left-hand side of the production.
			# @param [String, nil]	expression	Right-hand side of the production.
			# @param [Symbol, nil]	precedence	Symbol representing the precedence of this produciton.
			# @param [Proc]		action		Action associated with this production.
			#
			# @return [void]
			def production(symbol, expression = nil, precedence = nil, &action)
				
				# Check the symbol.
				if not (symbol.is_a?(Symbol) or symbol.is_a?(String)) or not CFG::is_nonterminal?(symbol)
					riase ParserConstructionException, 'Production symbols must be Strings or Symbols and be in all lowercase.'
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
			alias :p :production
			
			# This method uses lookahead sets and precedence information to
			# resolve conflicts and remove unnecessary reduce actions.
			#
			# @param [Boolean] do_lookahead	Prune based on lookahead sets or not.
			# @param [Boolean] do_precedence	Prune based on precedence or not.
			#
			# @return [void]
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
							
							lookahead = Array.new
							
							# Build the lookahead set.
							@states.each do |state1|
								if self.check_reachability(state1, state0, production.rhs)
									lookahead |= self.grammar_prime.follow_set("#{state1.id}_#{production.lhs}".to_sym)
								end
							end
							
							# Translate the G' follow symbols into G lookahead
							# symbols.
							lookahead = lookahead.map { |sym| sym.to_s.split('_').last.to_sym }.uniq
							
							# Here we remove the unnecessary reductions.
							# If there are error productions we need to
							# scale back the amount of pruning done.
							(terms - lookahead).each do |sym|
								if not (terms.include?(:ERROR) and not state0.conflict_on?(sym))
									state0.actions[sym].delete(reduction)
								end
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
							
							resolve_ok = actions.inject(true) do |m, a|
								if a.is_a?(Reduce)
									m and @production_precs[a.id]
								else
									m
								end
							end and actions.inject(false) { |m, a| m or a.is_a?(Shift) }
							
							if @token_precs[symbol] and resolve_ok
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
									#  * The token is right associative and the current action is a Shift
									if prec > max_prec or (prec == max_prec and tassoc == (a.is_a?(Shift) ? :right : :left))
										max_prec			= prec
										selected_action	= a
										
									elsif prec == max_prec and assoc == :nonassoc
										raise ParserConstructionException, 'Non-associative token found during conflict resolution.'
										
									end
								end
								
								state0.actions[symbol] = [selected_action]
							end
						end
					end
				end
			end
			
			# This method is used to specify that the symbols in _symbols_
			# are right associative.  Subsequent calls to this method will
			# give their arguments higher precedence.
			#
			# @param [Array<Symbol>] symbols Symbols that are right-associative.
			#
			# @return [void]
			def right(*symbols)
				prec_level = @prec_counts[:right] += 1
				
				symbols.map { |s| s.to_sym }.each do |sym|
					@token_precs[sym] = [:right, prec_level]
				end
			end
			
			# Changes the starting symbol of the parser.
			#
			# @param [Symbol] symbol The starting symbol of the grammar.
			#
			# @return [void]
			def start(symbol)
				@grammar.start symbol
			end
		end
		
		####################
		# Instance Methods #
		####################
		
		# Instantiates a new parser and creates an environment to be
		# used for subsequent calls.
		def initialize
			@env = self.class::Environment.new
		end
	
		# Parses the given token stream using the encapsulated environment.
		#
		# @see .parse
		def parse(tokens, opts = {})
			self.class.parse(tokens, {:env => @env}.update(opts))
		end
		
		################################
		
		# All actions passed to Parser.producation and Parser.clause are
		# evaluated inside an instance of the Environment class or its
		# subclass (which must have the same name).
		class Environment
			# Indicates if an error was encountered and handled.
			#
			# @return [Boolean]
			attr_accessor :he
			
			# A list of all objects added using the *error* method.
			#
			# @return [Array<Object>]
			attr_reader :errors
			
			# Instantiate a new Environment object.
			def initialize
				self.reset
			end
			
			# Adds an object to the list of errors.
			#
			# @return [void]
			def error(o)
				@errors << o
			end
			
			# Returns a StreamPosition object for the symbol at location n,
			# indexed from zero.
			#
			# @param [Integer] n Index for symbol position.
			#
			# @return [StreamPosition] Position of symbol at index n.
			def pos(n)
				@positions[n]
			end
			
			# Reset any variables that need to be re-initialized between
			# parse calls.
			#
			# @return [void]
			def reset
				@errors	= Array.new
				@he		= false
			end
			
			# Setter for the *positions* array.
			#
			# @param [Array<StreamPosition>] positions
			#
			# @return [Array<StreamPosition>] The same array of positions.
			def set_positions(positions)
				@positions = positions
			end
		end
		
		# The ParseStack class is used by a Parser to keep track of state
		# during parsing.
		class ParseStack
			# @return [Integer] ID of this parse stack.
			attr_reader :id
			
			# @return [Array<Object>] Array of objects produced by {Reduce} actions.
			attr_reader :output_stack
			
			# @return [Array<Integer>] Array of states used when performing {Reduce} actions.
			attr_reader :state_stack
			
			# Instantiate a new ParserStack object.
			#
			# @param [Integer]				id			ID for this parse stack.  Used by GLR algorithm.
			# @param [Array<Object>]			ostack		Output stack.  Holds results of {Reduce} and {Shift} actions.
			# @param [Array<Integer>]		sstack		State stack.  Holds states that have been shifted due to {Shift} actions.
			# @param [Array<Integer>]		nstack		Node stack.  Holds dot language IDs for nodes in the parse tree.
			# @param [Array<Array<Integer>>]	connections	Integer pairs representing edges in the parse tree.
			# @param [Array<Symbol>]			labels		Labels for nodes in the parse tree.
			# @param [Array<StreamPosition>]	positions		Position data for symbols that have been shifted.
			def initialize(id, ostack = [], sstack = [0], nstack = [], connections = [], labels = [], positions = [])
				@id = id
				
				@node_stack	= nstack
				@output_stack	= ostack
				@state_stack	= sstack
				
				@connections	= connections
				@labels		= labels
				@positions	= positions
			end
			
			# Branch this stack, effectively creating a new copy of its
			# internal state.
			#
			# @param [Integer] new_id ID for the new ParseStack.
			#
			# @return [ParseStack]
			def branch(new_id)
				ParseStack.new(new_id, @output_stack.clone, @state_stack.clone, @node_stack.clone,
					@connections.clone, @labels.clone, @positions.clone)
			end
			
			# @return [StreamPosition] Position data for the last symbol on the stack.
			def position
				if @positions.empty?
					StreamPosition.new
				else
					@positions.last.clone
				end
			end
			
			# Push new state and other information onto the stack.
			#
			# @param [Integer]			state	ID of the shifted state.
			# @param [Object]			o		Value of Token that caused the shift.
			# @param [Symbol]			node0	Label for node in parse tree.
			# @param [StreamPosition]	position	Position token that got shifted.
			#
			# @return [void]
			def push(state, o, node0, position)
				@state_stack	<< state
				@output_stack	<< o
				@node_stack	<< @labels.length
				@labels		<< if CFG::is_terminal?(node0) and o then node0.to_s + "(#{o})" else node0 end
				@positions	<< position
				
				if CFG::is_nonterminal?(node0)
					@cbuffer.each do |node1|
						@connections << [@labels.length - 1, node1]
					end
				end
			end
			
			# Pop some number of objects off of the inside stacks.
			#
			# @param [Integer] n Number of object to pop off the stack.
			#
			# @return [Array<Array<Object, StreamPosition>>] Values popped from the output and positions stacks.
			def pop(n = 1)
				@state_stack.pop(n)
				
				# Pop the node stack so that the proper edges can be added
				# when the production's left-hand side non-terminal is
				# pushed onto the stack.
				@cbuffer = @node_stack.pop(n)
				
				[@output_stack.pop(n), @positions.pop(n)]
			end
			
			# Fetch the result stored in this ParseStack.  If there is more
			# than one object left on the output stack there is an error.
			#
			# @return [Object] The end result of this parse stack.
			def result
				if @output_stack.length == 1
					return @output_stack.last
				else
					raise InternalParserException, "The parsing stack should have 1 element on the output stack, not #{@output_stack.length}."
				end
			end
			
			# @return [Integer] Current state of this ParseStack.
			def state
				@state_stack.last
			end
			
			# @return [String] Representation of the parse tree in the DOT langauge.
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
		
		# The State class is used to represent sets of items and actions to be
		# used during parsing.
		class State
			# @return [Integer] State's ID.
			attr_accessor :id
			
			# @return [Array<CFG::Item>] Item objects that comprise this state.
			attr_reader :items
			
			# @return [Array<Action>] Action objects that represent the actions that should be taken when various inputs are observed.
			attr_reader :actions
			
			# Instantiate a new State object.
			#
			# @param [Array<Token>]		tokens	Tokens that represent this state.
			# @param [Array<CFG::Item>]	items	Items that make up this state.
			def initialize(tokens, items = [])
				@id		= nil
				@items	= items
				@actions	= tokens.inject(Hash.new) { |h, t| h[t] = Array.new; h }
			end
			
			# Compare one State to another.  Two States are equal if they
			# have the same items or, if the items have been cleaned, if
			# the States have the same ID.
			#
			# @param [State] other Another State to compare to.
			#
			# @return [Boolean]
			def ==(other)
				if self.items and other.items then self.items == other.items else self.id == other.id end
			end
			
			# Add a Reduce action to the state.
			#
			# @param [Integer] production_id ID of production to add to this state.
			#
			# @return [void]
			def add_reduction(production_id)
				action = Reduce.new(production_id)
				
				# Reduce actions are not allowed for the ERROR terminal.
				@actions.each { |k, v| if CFG::is_terminal?(k) and k != :ERROR then v << action end }
			end
			
			# @param [CFG::Item] item Item to add to this state.
			def append(item)
				if item.is_a?(CFG::Item) and not @items.include?(item) then @items << item end
			end
			alias :<< :append
			
			# Clean this State by removing the list of {CFG::Item} objects.
			#
			# @return [void]
			def clean
				@items = nil
			end
			
			# Close this state using *productions*.
			#
			# @param [Array<CFG::Production>] productions Productions used to close this state.
			#
			# @return [vod]
			def close(productions)
				self.each do |item|
					if (next_symbol = item.next_symbol) and CFG::is_nonterminal?(next_symbol)
						productions[next_symbol].each { |p| self << p.to_item }
					end
				end
			end
			
			# Checks to see if there is a conflict in this state, given a
			# input of *sym*.  Returns :SR if a shift/reduce conflict is
			# detected and :RR if a reduce/reduce conflict is detected.  If
			# no conflict is detected nil is returned.
			#
			# @param [Symbol] sym Symbol to check for conflicts on.
			#
			# @return [:SR, :RR, nil]
			def conflict_on?(sym)
				
				reductions	= 0
				shifts		= 0
				
				@actions[sym].each do |action|
					if action.is_a?(Reduce)
						reductions += 1
						
					elsif action.is_a?(Shift)
						shifts += 1
						
					end
				end
				
				if shifts == 1 and reductions > 0
					:SR
				elsif reductions > 1
					:RR
				else
					nil
				end
			end
			
			# Iterate over the state's items.
			#
			# @return [void]
			def each
				@items.each {|item| yield item}
			end
			
			# Specify an Action to perform when the input token is *symbol*.
			#
			# @param [Symbol] symbol Symbol to add action for.
			# @param [Action] action Action for symbol.
			#
			# @return [void]
			def on(symbol, action)
				if @actions.key?(symbol)
					@actions[symbol] << action
				else
					raise ParserConstructionException, "Attempting to set action for token (#{symbol}) not seen in grammar definition."
				end
			end
			
			# Returns that actions that should be taken when the input token
			# is *symbol*.
			#
			# @param [Symbol] symbol Symbol we want the actions for.
			#
			# @return [Array<Action>] Actions that should be taken.
			def on?(symbol)
				@actions[symbol].clone
			end
		end
		
		# The Action class is used to indicate what action the parser should
		# take given a current state and input token.
		class Action
			# @return [Integer] ID of this action.
			attr_reader :id
			
			# @param [Integer] id ID of this action.
			def initialize(id = nil)
				@id = id
			end
		end
		
		# The Accept class indicates to the parser that it should accept the
		# current parse tree.
		class Accept < Action
			# @return [String] String representation of this action.
			def to_s
				"Accept"
			end
		end
		
		# The GoTo class indicates to the parser that it should goto the state
		# specified by GoTo.id.
		class GoTo < Action
			# @return [String] String representation of this action.
			def to_s
				"GoTo #{self.id}"
			end
		end
		
		# The Reduce class indicates to the parser that it should reduce the
		# input stack by the rule specified by Reduce.id.
		class Reduce < Action
			# @return [String] String representation of this action.
			def to_s
				"Reduce by Production #{self.id}"
			end
		end
		
		# The Shift class indicates to the parser that it should shift the
		# current input token.
		class Shift < Action
			# @return [String] String representation of this action.
			def to_s
				"Shift to State #{self.id}"
			end
		end
	end
end
