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

module RLTK # :nodoc:
	
	# An exception class that represents a problem with a context-free
	# grammar's definition.
	class GrammarError < Exception; end
	
	# The CFG class is used to represent context-free grammars.  It is used by
	# the RLTK::Parser class to represent the parser's grammar, but can also be
	# used to manipulate arbitrary CFGs.
	class CFG
		
		# The start symbol for the grammar.
		attr_reader :start_symbol
		
		# The current left-hand side symbol.  This is used by the
		# CFG.production method to wrapp CFG.clause calls.
		attr_accessor :curr_lhs
		
		#################
		# Class Methods #
		#################
		
		# Tests to see if a symbol is a terminal symbol, as used by the CFG
		# class.
		def self.is_terminal?(sym)
			sym and (s = sym.to_s) == s.upcase
		end
		
		# Tests to see if a symbol is a non-terminal symbol, as used by the
		# CFG class.
		def self.is_nonterminal?(sym)
			sym and (s = sym.to_s) == s.downcase
		end
		
		####################
		# Instance Methods #
		####################
		
		# Instantiates a new CFG object that uses _callback_ to inform the
		# programmer of the generation of new productions due to EBNF
		# operators.
		def initialize(&callback)
			@curr_lhs			= nil
			@callback			= callback || Proc.new {}
			@lexer			= Lexers::EBNF.new
			@production_counter	= -1
			@start_symbol		= nil
			@wrapper_symbol	= nil
			
			@productions_id	= Hash.new
			@productions_sym	= Hash.new { |h, k| h[k] = [] }
			@production_buffer	= Array.new
			
			@terms	= Hash.new(false).update({:EOS => true})
			@nonterms	= Hash.new(false)
			
			@firsts	= Hash.new
			@follows	= Hash.new
		end
		
		# Adds _production_ to the appropriate internal data structures.
		def add_production(production)
			@productions_sym[production.lhs] << (@productions_id[production.id] = production)
		end
		
		# Sets the EBNF callback to _callback_.
		def callback(&callback)
			@callback = callback || Proc.new {}
		end
		
		# This function MUST be called inside a CFG.production block.  It will
		# make a new production with the left-hand side specified by the
		# CFG.production call's argument.  This is the function that is
		# responsible for removing EBNF symbols from the grammar.
		def clause(expression)
			if not @curr_lhs
				raise GrammarError, 'CFG.clause called outside of CFG.production block.'
			end
			
			lhs		= @curr_lhs.to_sym
			rhs		= Array.new
			tokens	= @lexer.lex(expression)
			
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
							when :'?'
								self.get_question(tvalue0)
							
							when :*
								self.get_star(tvalue0)
							
							when :+
								self.get_plus(tvalue0)
							
							else
								tvalue0
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
		
		# Returns the _first_ set for _sentence_.  _Sentence_ may be either a
		# single symbol or an array of symbols.
		def first_set(sentence)
			if sentence.is_a?(Symbol)
				self.first_set_prime(sentence)
				
			elsif sentence.inject(true) { |m, sym| m and self.symbols.include?(sym) }
				set0 = []
				all_have_empty = true
				
				sentence.each do |sym|
					set0 |= (set1 = self.first_set(sym)) - [:'ɛ']
					
					break if not (all_have_empty = set1.include?(:'ɛ'))
				end
				
				if all_have_empty then set0 + [:'ɛ'] else set0 end
			else
				nil
			end
		end
		
		# This function is responsible for calculating the _first_ set of
		# individual symbols.  CFG.first_set is a wrapper around this function
		# to provide support for calculating the _first_ set for sentences.
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
						if production.rhs == []
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
									set0 |= (set1 = self.first_set_prime(sym1, seen_lh_sides << sym1)) - [:'ɛ']
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
				nil
			end
		end
		
		# Returns the _follow_ set for a given symbol.  The second argument is
		# used to avoid infinite recursion when mutually recursive rules are
		# encountered.
		def follow_set(sym0, seen_lh_sides = [])
			# Memoize the result for later.
			@follows[sym0] ||=
			
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
				
				set0
			else
				[]
			end
		end
		
		# Builds productions used to eliminate the + EBNF operator.
		def get_plus(symbol)
			new_symbol = (symbol.to_s.downcase + '_plus').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_plus: token | token token_plus
				
				# 1st production
				self.add_production(production = Production.new(self.next_id, new_symbol, [symbol]))
				@callback.call(production, :+, :first)
				
				# 2nd production
				self.add_production(production = Production.new(self.next_id, new_symbol, [symbol, new_symbol]))
				@callback.call(production, :+, :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# Builds productions used to eliminate the ? EBNF operator.
		def get_question(symbol)
			new_symbol = (symbol.to_s.downcase + '_question').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# nonterm_question: | nonterm
				
				# 1st (empty) production.
				self.add_production(production = Production.new(self.next_id, new_symbol, []))
				@callback.call(production, :'?', :first)
				
				# 2nd production
				self.add_production(production = Production.new(self.next_id, new_symbol, [symbol]))
				@callback.call(production, :'?', :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# Builds productions used to eliminate the * EBNF operator.
		def get_star(symbol)
			new_symbol = (symbol.to_s.downcase + '_star').to_sym
			
			if not @productions_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_star: | token token_star
				
				# 1st (empty) production
				self.add_production(production = Production.new(self.next_id, new_symbol, []))
				@callback.call(production, :*, :first)
				
				# 2nd production
				self.add_production(production = Production.new(self.next_id, new_symbol, [symbol, new_symbol]))
				@callback.call(production, :*, :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		# Returns the ID for the next production to be defined.
		def next_id
			@production_counter += 1
		end
		
		# Returns all of the non-terminal symbols used in the gramar's
		# definition.
		def nonterms
			@nonterms.keys
		end
		
		# Builds a new production with the left-hand side value of _symbol_.
		# If _expression_ is specified it is take as the right-hand side of
		# production.  If _expression_ is nil then _block_ is evaluated, and
		# expected to make one or more calls to CFG.clause.
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
		
		# If _by_ is :sym, returns a hash of the grammar's productions, using
		# the productions' left-hand side symbol as the key.  If _by_ is :id
		# an array of productions is returned in the order of their
		# definition.
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
		def start(symbol)
			if not CFG::is_nonterminal?(symbol)
				raise GrammarError, 'Start symbol must be a non-terminal.'
			end
			
			@start_symbol = symbol
		end
		
		# Returns a list of symbols encountered in the grammar's definition.
		def symbols
			self.terms + self.nonterms
		end
		
		# Returns a list of all terminal symbols encountered in the grammar's
		# definition.
		def terms
			@terms.keys
		end
		
		# Oddly enough, the Production class represents a production in a
		# context-free grammar.
		class Production
			attr_reader :id
			attr_reader :lhs
			attr_reader :rhs
			
			# Instantiates a new Production object with the specified ID,
			# and left- and right-hand sides.
			def initialize(id, lhs, rhs)
				@id	= id
				@lhs	= lhs
				@rhs	= rhs
			end
			
			# Comparese on production to another.  Returns true only if the
			# left- and right- hand sides match.
			def ==(other)
				self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			# Makes a new copy of the production.
			def copy
				Production.new(@id, @lhs, @rhs.clone)
			end
			
			# Locates the last terminal in the right-hand side of a
			# production.
			def last_terminal
				@rhs.inject(nil) { |m, sym| if CFG::is_terminal?(sym) then sym else m end }
			end
			
			# Returns a new Item based on this production.
			def to_item
				Item.new(0, @id, @lhs, @rhs)
			end
			
			# Returns a string representation of this production.
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.map { |s| s.to_s }.join(' ')}"
			end
		end
		
		# The Item class represents a CFG production with dot in it.
		class Item < Production
			attr_reader :dot
			
			# Instantiates a new Item object with a dot located before the
			# symbol at index _dot_ of the right-hand side.  The remaining
			# arguments (_args_) should be as specified by
			# Production.initialize.
			def initialize(dot, *args)
				super(*args)
				
				# The Dot indicates the NEXT symbol to be read.
				@dot = dot
			end
			
			# Compares two items.
			def ==(other)
				self.dot == other.dot and self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			# Moves the items dot forward by one if the end of the right-hand
			# side hasn't already been reached.
			def advance
				if @dot < @rhs.length
					@dot += 1
				end
			end
			
			# Tests to see if the dot is at the end of the right-hand side.
			def at_end?
				@dot == @rhs.length
			end
			
			# Produces a new copy of this item.
			def copy
				Item.new(@dot, @id, @lhs, @rhs.clone)
			end
			
			# Returns the symbol located after the dot.
			def next_symbol
				@rhs[@dot]
			end
			
			# Returns a string representation of this item.
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.map { |s| s.to_s }.insert(@dot, '·').join(' ') }"
			end
		end
	end
end
