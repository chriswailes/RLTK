# encoding: utf-8

# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/24
# Description:	This file contains the a class representing a context-free
#			grammar.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/lexers/ebnf'

#######################
# Classes and Modules #
#######################

module RLTK
	# An exception class that represents a problem with a context-free
	# grammar's definition.
	class GrammarError < StandardError; end
	
	# The CFG class is used to represent context-free grammars.  It is used by
	# the RLTK::Parser class to represent the parser's grammar, but can also be
	# used to manipulate arbitrary CFGs.
	class CFG
		
		# @return [Symbol] The grammar's starting symbol.
		attr_reader :start_symbol
		
		# This is used by the {CFG#production} method to wrap {CFG#clause}
		# calls.
		#
		# @return [Symbol] The current left-hand side symbol.
		attr_accessor :curr_lhs
		
		#################
		# Class Methods #
		#################
		
		# Tests to see if a symbol is a terminal symbol, as used by the CFG
		# class.
		#
		# @param [Symbol] sym The symbol to test.
		#
		# @return [Boolean]
		def self.is_terminal?(sym)
			sym and (s = sym.to_s) == s.upcase
		end
		
		# Tests to see if a symbol is a non-terminal symbol, as used by the
		# CFG class.
		#
		# @param [Symbol] sym The symbol to test.
		#
		# @return [Boolean]
		def self.is_nonterminal?(sym)
			sym and (s = sym.to_s) == s.downcase
		end
		
		####################
		# Instance Methods #
		####################
		
		# Instantiates a new CFG object that uses *callback* to inform the
		# programmer of the generation of new productions due to EBNF
		# operators.
		#
		# @param [Proc] callback A Proc object to be called when EBNF operators are expanded.
		def initialize(&callback)
			@curr_lhs           = nil
			@callback           = callback || Proc.new {}
			@lexer              = Lexers::EBNF.new
			@production_counter = -1
			@start_symbol       = nil
			@wrapper_symbol     = nil
			
			@productions_id     = Hash.new
			@productions_sym    = Hash.new { |h, k| h[k] = [] }
			@production_buffer  = Array.new
			
			@terms    = Hash.new(false).update({:EOS => true})
			@nonterms = Hash.new(false)
			
			@firsts   = Hash.new
			@follows  = Hash.new { |h,k| h[k] = Array.new }
		end
		
		# Adds *production* to the appropriate internal data structures.
		#
		# @param [Production] production The production to add to the grammar.
		#
		# @return [void]
		def add_production(production)
			@productions_sym[production.lhs] << (@productions_id[production.id] = production)
			
			production
		end
		
		# Sets the EBNF callback to *callback*.
		#
		# @param [Proc] callback A Proc object to be called when EBNF operators are expanded and list productions are added.
		#
		# @return [void]
		def callback(&callback)
			@callback = callback if callback
			
			nil
		end
		
		# This function MUST be called inside a CFG.production block.  It will
		# make a new production with the left-hand side specified by the
		# CFG.production call's argument.  This is the function that is
		# responsible for removing EBNF symbols from the grammar.
		#
		# @param [String, Symbol] expression The right-hand side of a CFG production.
		#
		# @return [Production]
		def clause(expression)
			raise GrammarError, 'CFG#clause called outside of CFG#production block.' if not @curr_lhs
			
			lhs		= @curr_lhs.to_sym
			rhs		= Array.new
			tokens	= @lexer.lex(expression.to_s)
			
			# Set this as the start symbol if there isn't one already
			# defined.
			@start_symbol ||= lhs
			
			# Remove EBNF tokens and replace them with new productions.
			tokens.each_index do |i|
				ttype0	= tokens[i].type
				tvalue0	= tokens[i].value
				
				if ttype0 == :TERM or ttype0 == :NONTERM
					
					# Add this symbol to the correct collection.
					(ttype0 == :TERM ? @terms : @nonterms)[tvalue0] = true
					
					if i + 1 < tokens.length
						ttype1	= tokens[i + 1].type
						tvalue1	= tokens[i + 1].value
						
						rhs <<
						case ttype1
						when :'?'	then self.get_question(tvalue0)
						when :*	then self.get_star(tvalue0)
						when :+	then self.get_plus(tvalue0)
						else			tvalue0
						end
					else
						rhs << tvalue0
					end
				end
			end
			
			# Make the production.
			@production_buffer << (production = Production.new(self.next_id, lhs, rhs))
			
			# Make sure the production symbol is collected.
			@nonterms[lhs] = true
			
			# Add the new production to our collections.
			self.add_production(production)
			
			return production
		end
		
		# This method adds the necessary productions for empty lists to the
		# grammar.  These productions are named `symbol`, `symbol + '_prime'`
		# and `symbol + '_elements'`.  The separator may be an empty string,
		# a single parser symbol (as a String or Symbol), or a String
		# containing multiple symbols.
		#
		# @param [Symbol]						symbol		The name of the production to add.
		# @param [String, Symbol, Array<String>]	list_elements	Expression(s) that may appear in the list.
		# @param [Symbol, String]				separator		The list separator symbol or symbols.
		#
		# @return [void]
		def empty_list_production(symbol, list_elements, separator = '')
			# Add the items for the following productions:
			#
			# symbol: | symbol_prime
			
			prime = symbol.to_s + '_prime'
			
			# 1st Production
			production, _ = self.production(symbol, '')
			@callback.call(:elp, :first, production)
			
			# 2nd Production
			production, _ = self.production(symbol, prime.to_s)
			@callback.call(:elp, :second, production)
			
			self.nonempty_list(prime, list_elements, separator)
		end
		alias :empty_list :empty_list_production
		
		# This function calculates the *first* set of a series of tokens.  It
		# uses the {CFG#first_set} helper function to find the first set of
		# individual symbols.
		#
		# @param [Symbol, Array<Symbol>] sentence Sentence to find the *first set* for.
		#
		# @return [Array<Symbol>] The *first set* for the given sentence.
		def first_set(sentence)
			if sentence.is_a?(Symbol)
				first_set_prime(sentence)
				
			elsif sentence.inject(true) { |m, sym| m and self.symbols.include?(sym) }
				set0 = []
				all_have_empty = true
				
				sentence.each do |sym|
					set0 |= (set1 = self.first_set(sym)) - [:'ɛ']
					
					break if not (all_have_empty = set1.include?(:'ɛ'))
				end
				
				if all_have_empty then set0 + [:'ɛ'] else set0 end
			end
		end
		
		# This function is responsible for calculating the *first* set of
		# individual symbols.
		#
		# @param [Symbol]		sym0			The symbol to find the *first set* of.
		# @param [Array<Symbol>]	seen_lh_sides	Previously seen LHS symbols.
		#
		# @return [Array<Symbol>]
		def first_set_prime(sym0, seen_lh_sides = [])
			if self.symbols.include?(sym0)
				# Memoize the result for later.
				@firsts[sym0] ||=
				if CFG::is_terminal?(sym0)
					# If the symbol is a terminal, it is the only symbol in
					# its follow set.
					[sym0]
				else
					set0 = []
					
					@productions_sym[sym0].each do |production|
						if production.rhs.empty?
							# If this is an empty production we should
							# add the empty string to the First set.
							set0 << :'ɛ'
						else
							all_have_empty = true
							
							production.rhs.each do |sym1|
								
								set1 = []
								
								# Grab the First set for the current
								# symbol in this production.
								if not seen_lh_sides.include?(sym1)
									set0 |= (set1 = first_set_prime(sym1, seen_lh_sides << sym1)) - [:'ɛ']
								end
								
								break if not (all_have_empty = set1.include?(:'ɛ'))
							end
							
							# Add the empty production if this production
							# is all non-terminals that can be reduced to
							# the empty string.
							set0 << :'ɛ' if all_have_empty
						end
					end
					
					set0.uniq
				end
			else
				[]
			end
		end
		private :first_set_prime
		
		# Returns the *follow* set for a given symbol.  The second argument is
		# used to avoid infinite recursion when mutually recursive rules are
		# encountered.
		#
		# @param [Symbol]		sym0			The symbol to find the *follow set* for.
		# @param [Array<Symbol>]	seen_lh_sides	Previously seen LHS symbols.
		#
		# @return [Array<Symbol>]
		def follow_set(sym0, seen_lh_sides = [])
			
			# Use the memoized set if possible.
			return @follows[sym0] if @follows.has_key?(sym0)
			
			if @nonterms[sym0]
				set0 = []
				
				# Add EOS to the start symbol's follow set.
				set0 << :EOS if sym0 == @start_symbol
				
				@productions_id.values.each do |production|
					production.rhs.each_with_index do |sym1, i|
						if i + 1 < production.rhs.length
							if sym0 == sym1
								set0 |= (set1 = self.first_set(production.rhs[(i + 1)..-1])) - [:'ɛ']
								
								set0 |= self.follow_set(production.lhs) if set1.include?(:'ɛ')
							end
						elsif sym0 != production.lhs and sym0 == sym1 and not seen_lh_sides.include?(production.lhs)
							set0 |= self.follow_set(production.lhs, seen_lh_sides << production.lhs)
						end
					end
				end
				
				if seen_lh_sides.empty? or not set0.empty?
					# Memoize the result for later.
					@follows[sym0] |= set0
				else
					set0
				end
			else
				[]
			end
		end
		
		# Builds productions used to eliminate the + EBNF operator.
		#
		# @param [Symbol] symbol Symbol to expand.
		#
		# @return [Symbol]
		def get_plus(symbol)
			new_symbol = (symbol.to_s.downcase + '_plus').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_plus: token | token token_plus
				
				# 1st production
				production = self.add_production(Production.new(self.next_id, new_symbol, [symbol]))
				@callback.call(:+, :first, production)
				
				# 2nd production
				production = self.add_production(Production.new(self.next_id, new_symbol, [new_symbol, symbol]))
				@callback.call(:+, :second, production)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# Builds productions used to eliminate the ? EBNF operator.
		#
		# @param [Symbol] symbol Symbol to expand.
		#
		# @return [Symbol]
		def get_question(symbol)
			new_symbol = (symbol.to_s.downcase + '_question').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# nonterm_question: | nonterm
				
				# 1st (empty) production.
				production = self.add_production(Production.new(self.next_id, new_symbol, []))
				@callback.call(:'?', :first, production)
				
				# 2nd production
				production = self.add_production(Production.new(self.next_id, new_symbol, [symbol]))
				@callback.call(:'?', :second, production)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# Builds productions used to eliminate the * EBNF operator.
		#
		# @param [Symbol] symbol Symbol to expand.
		#
		# @return [Symbol]
		def get_star(symbol)
			new_symbol = (symbol.to_s.downcase + '_star').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_star: | token token_star
				
				# 1st (empty) production
				production = self.add_production(Production.new(self.next_id, new_symbol, []))
				@callback.call(:*, :first, production)
				
				# 2nd production
				production = self.add_production(Production.new(self.next_id, new_symbol, [new_symbol, symbol]))
				@callback.call(:*, :second, production)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# @return [Integer] ID for the next production to be defined.
		def next_id
			@production_counter += 1
		end
		
		# This method adds the necessary productions for non-empty lists to
		# the grammar.  These productions are named `symbol` and
		# `symbol + '_elements'`.  The separator may be an empty string,
		# a single parser symbol (as a String or Symbol), or a String
		# containing multiple symbols.
		#
		# @param [Symbol]						symbol		The name of the production to add.
		# @param [String, Symbol, Array<String>]	list_elements	Expression(s) that may appear in the list.
		# @param [Symbol, String]				separator		The list separator symbol or symbols.
		#
		# @return [void]
		def nonempty_list_production(symbol, list_elements, separator = '')
			# Add the items for the following productions:
			#
			# symbol: symbol_elements | symbol separator symbol_elements
			#
			# symbol_elements: #{list_elements.join('|')}
			
			if list_elements.is_a?(String) or list_elements.is_a?(Symbol)
				list_elements = [list_elements.to_s]
				
			elsif list_elements.is_a?(Array)
				if list_elements.empty?
					raise ArgumentError, 'Parameter list_elements must not be empty.'
				else
					list_elements.map! { |el| el.to_s }
				end
				
			else
				raise ArgumentError, 'Parameter list_elements must be a String, Symbol, or array of Strings and Symbols.'
			end
			
			symbol_elements = symbol.to_s + '_elements'
			
			# 1st Production
			production, _ = self.production(symbol, symbol_elements)
			@callback.call(:nelp, :first, production)
			
			# 2nd Production
			production, _ = self.production(symbol, "#{symbol} #{separator} #{symbol_elements}")
			@callback.call(:nelp, :second, production)
			
			# 3rd Productions
			list_elements.each do |el|
				production, _ = self.production(symbol_elements, el)
				@callback.call(:nelp, :third, production)
			end
		end
		alias :nonempty_list :nonempty_list_production
		
		# @return [Array<Symbol>] All terminal symbols used in the grammar's definition.
		def nonterms
			@nonterms.keys
		end
		
		# Builds a new production with the left-hand side value of *symbol*.
		# If *expression* is specified it is take as the right-hand side of
		# production.  If *expression* is nil then *block* is evaluated, and
		# expected to make one or more calls to {CFG#clause}.
		#
		# @param [Symbol]			symbol		The right-hand side of a production.
		# @param [String, Symbol]	expression	The left-hand side of a production.
		# @param [Proc]			block		Optional block for defining production clauses.
		#
		# @return [Array<Production>]
		def production(symbol, expression = nil, &block)
			@production_buffer = Array.new
			@curr_lhs = symbol
			
			if expression
				self.clause(expression)
			else
				self.instance_exec(&block)
			end
			
			@curr_lhs = nil
			return @production_buffer.clone
		end
		
		# If *by* is :sym, returns a hash of the grammar's productions, using
		# the productions' left-hand side symbol as the key.  If *by* is :id
		# an array of productions is returned in the order of their
		# definition.
		#
		# @param [:sym, :id] by The way in which productions should be returned.
		#
		# @return [Array<Production>, Hash{Symbol => Production}]
		def productions(by = :sym)
			if by == :sym
				@productions_sym
			elsif by == :id
				@productions_id
			else
				nil
			end
		end
		
		# Sets the start symbol for this grammar.
		#
		# @param [Symbol] symbol The new start symbol.
		#
		# @return [Symbol]
		def start(symbol)
			if not CFG::is_nonterminal?(symbol)
				raise GrammarError, 'Start symbol must be a non-terminal.'
			end
			
			@start_symbol = symbol
		end
		
		# @return [Array<Symbol>] All symbols used in the grammar's definition.
		def symbols
			self.terms + self.nonterms
		end
		
		# @return [Array<Symbol>] All terminal symbols used in the grammar's definition.
		def terms
			@terms.keys
		end
		
		# Oddly enough, the Production class represents a production in a
		# context-free grammar.
		class Production
			# @return [Integer] ID of this production.
			attr_reader :id
			
			# @return [Symbol] Left-hand side of this production.
			attr_reader :lhs
			
			# @return [Array<Symbol>] Right-hand side of this production.
			attr_reader :rhs
			
			# Instantiates a new Production object with the specified ID,
			# and left- and right-hand sides.
			#
			# @param [Integer]		id	ID number of this production.
			# @param [Symbol]		lhs	Left-hand side of the production.
			# @param [Array<Symbol>]	rhs	Right-hand side of the production.
			def initialize(id, lhs, rhs)
				@id	= id
				@lhs	= lhs
				@rhs	= rhs
			end
			
			# Comparese on production to another.  Returns true only if the
			# left- and right- hand sides match.
			#
			# @param [Production] other Another production to compare to.
			#
			# @return [Boolean]
			def ==(other)
				self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			# @return [Production] A new copy of this production.
			def copy
				Production.new(@id, @lhs, @rhs.clone)
			end
			
			# @return [Symbol] The last terminal in the right-hand side of the production.
			def last_terminal
				@rhs.inject(nil) { |m, sym| if CFG::is_terminal?(sym) then sym else m end }
			end
			
			# @return [Item] An Item based on this production.
			def to_item
				Item.new(0, @id, @lhs, @rhs)
			end
			
			# Returns a string representation of this production.
			#
			# @param [Integer] padding The ammount of padding spaces to add to the beginning of the string.
			#
			# @return [String]
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.empty? ? 'ɛ' : @rhs.map { |s| s.to_s }.join(' ')}"
			end
		end
		
		# The Item class represents a CFG production with dot in it.
		class Item < Production
			# @return [Integer] Index of the next symbol in this item.
			attr_reader :dot
			
			# Instantiates a new Item object with a dot located before the
			# symbol at index *dot* of the right-hand side.  The remaining
			# arguments (*args*) should be as specified by
			# {Production#initialize}.
			#
			# @param [Integer]        dot   Location of the dot in this Item.
			# @param [Array<Object>]  args  (see {Production#initialize})
			def initialize(dot, *args)
				super(*args)
				
				# The Dot indicates the NEXT symbol to be read.
				@dot = dot
			end
			
			# Compares two items.
			#
			# @param [Item] other Another item to compare to.
			#
			# @return [Boolean]
			def ==(other)
				self.dot == other.dot and self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			# Moves the items dot forward by one if the end of the right-hand
			# side hasn't already been reached.
			#
			# @return [Integer, nil]
			def advance
				if @dot < @rhs.length
					@dot += 1
				end
			end
			
			# Tests to see if the dot is at the end of the right-hand side.
			#
			# @return [Boolean]
			def at_end?
				@dot == @rhs.length
			end
			
			# @return [Item]  A new copy of this item.
			def copy
				Item.new(@dot, @id, @lhs, @rhs.clone)
			end
			
			# Returns the symbol located after the dot.
			#
			# @return [Symbol] Symbol located after the dot (at the index indicated by the {#dot} attribute).
			def next_symbol
				@rhs[@dot]
			end
			
			# Returns a string representation of this item.
			#
			# @param [Integer]  padding  The ammount of padding spaces to add to the beginning of the string.
			#
			# @return [String]
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.map { |s| s.to_s }.insert(@dot, '·').join(' ') }"
			end
		end
	end
end
