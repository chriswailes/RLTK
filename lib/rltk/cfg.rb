# encoding: utf-8

# Author:      Chris Wailes <chris.wailes+rltk@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/03/24
# Description: This file contains the a class representing a context-free
#              grammar.

############
# Requires #
############

# Standard Library
require 'set'

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

		# @return [Symbol]  The grammar's starting symbol.
		attr_reader :start_symbol

		# This is used by the {CFG#production} method to wrap {CFG#clause}
		# calls.
		#
		# @return [Symbol]  The current left-hand side symbol.
		attr_accessor :curr_lhs

		#################
		# Class Methods #
		#################

		# Tests to see if a symbol is a terminal symbol, as used by the CFG
		# class.
		#
		# @param [Symbol]  sym  The symbol to test.
		#
		# @return [Boolean]
		def self.is_terminal?(sym)
			sym and (s = sym.to_s) == s.upcase
		end

		# Tests to see if a symbol is a non-terminal symbol, as used by the
		# CFG class.
		#
		# @param [Symbol]  sym  The symbol to test.
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
		# @param [Proc]  callback  A Proc object to be called when EBNF operators are expanded.
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

			@terms    = Set.new([:EOS])
			@nonterms = Set.new

			@firsts   = Hash.new
			@follows  = Hash.new { |h,k| h[k] = Array.new }
		end

		# Adds *production* to the appropriate internal data structures.
		#
		# @param [Production]  production  The production to add to the grammar.
		#
		# @return [void]
		def add_production(production)
			@productions_sym[production.lhs] << (@productions_id[production.id] = production)

			production
		end

		# Builds a production representing a (possibly empty) list of tokens.
		# These tokens may optionally be separated by a provided token.  This
		# function is used to eliminate the EBNF * operator.
		#
		# @param [Symbol]                         name           The name of the production to add
		# @param [String, Symbol, Array<String>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                 separator      The list separator symbol or symbols
		#
		# @return [void]
		def list(name, list_elements, separator: '')
			self.build_list_production(name, list_elements, separator, true)
		end

		# Builds a production representing a non-empty list of tokens.  These
		# tokens may optionally be separated by a provided token.  This
		# function is used to eliminate the EBNF + operator.
		#
		# @param [Symbol]                                 name           The name of the production to add
		# @param [String, Symbol, Array<String, Symbol>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                         separator      The list separator symbol or symbols
		#
		# @return [void]
		def nonempty_list(name, list_elements, separator: '')
			self.build_list_production(name, list_elements, separator, false)
		end

		# If the production already exists it will be returned.  If it does not
		# exist then it will be created and then returned.
		#
		# @param [Symbol]                         name           The name of the production to add
		# @param [String, Symbol, Array<String>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                 separator      The list separator symbol or symbols
		#
		# @return [void]
		def get_list_production(name, list_elements, separator = '')
			if @nonterms.include?(name)
				name

			else
				self.build_list_production(name, list_elements, separator, true)
			end
		end
		alias :get_list :get_list_production

		# Builds a production representing a (possibly empty) list of tokens.
		# These tokens may optionally be separated by a provided token.  This
		# function is used to eliminate the EBNF * operator.
		#
		# @param [Symbol]                         name           The name of the production to add
		# @param [String, Symbol, Array<String>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                 separator      The list separator symbol or symbols
		#
		# @return [void]
#		def build_list_production(name, list_elements, separator = '')
#			# Add the items for the following productions:
#			#
#			# name: | name_prime

#			name_prime = "#{name}_prime".to_sym

#			# 1st Production
#			production, _ = self.production(name, '')
#			@callback.call(:elp, :empty, production)

#			# 2nd Production
#			production, _ = self.production(name, name_prime)
#			@callback.call(:elp, :nonempty, production)

#			# Add remaining productions via nonempty_list helper.
#			self.nonempty_list(name_prime, list_elements, separator)

#			name
#		end
#		alias :list :build_list_production

		# If the production already exists it will be returned.  If it does not
		# exist then it will be created and then returned.
		#
		# @param [Symbol]                         name           The name of the production to add
		# @param [String, Symbol, Array<String>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                 separator      The list separator symbol or symbols
		#
		# @return [void]
		def get_nonempty_list_production(name, list_elements, separator = '')
			if @nonterms.include?(name)
				name

			else
				self.build_list_production(name, list_elements, separator, false)
			end
		end
		alias :get_nonempty_list :get_nonempty_list_production

		# Builds either an empty or non-empty list production.  These tokens
		# may optionally be separated by a provided token.  This function is
		# used to eliminate the EBNF + and * operators.
		#
		# @param [Symbol]                                 name           The name of the production to add
		# @param [String, Symbol, Array<String, Symbol>]  list_elements  Expression(s) that may appear in the list
		# @param [Symbol, String]                         separator      The list separator symbol or symbols
		# @param [Boolean]                                empty          If the list may be empty or not
		#
		# @return [void]
		def build_list_production(name, list_elements, separator, empty)
			# Add the items for the following productions:
			#
			# If there is only one list element:
			#
			#   # For non-empty lists
			#   name: list_element | name separator list_element
			#
			#   # For empty lists
			#   name: ɛ | name separator list_element
			#
			# else
			#
			#   # For non-empty lists
			#   name: name_list_elements | name separator name_list_elements
			#
			#   name_list_elements: #{list_elements.join('|')}
			#
			#   # For empty lists
			#   name: ɛ | name separator name_list_elements
			#
			#   name_list_elements: #{list_elements.join('|')}

			if separator != '' and empty
				# Add the items for the following productions:
				#
				# name: | name_prime

				name_prime = "#{name}_prime".to_sym

				# 1st Production
				production, _ = self.production(name, '')
				@callback.call(:list, :empty_wrapper, production) # FIXME []

				# 2nd Production
				production, _ = self.production(name, name_prime)
				@callback.call(:list, :nonempty_wrapper, production) # FIXME xs

				# Add remaining productions via nonempty_list helper.
				self.build_list_production(name_prime, list_elements, separator, false)
			else

				build_elements_productions = false

				list_element_string =
				if list_elements.is_a?(Array)
					if list_elements.empty?
						raise ArgumentError,
							  'Parameter list_elements must not be empty.'

					elsif list_elements.length == 1
						list_elements.first

					else
						build_elements_productions = true
						"#{name}_list_elements"
					end
				else
					list_elements
				end

				list_element_selected_string = list_element_string.to_s.split.map { |s| ".#{s}" }.join(' ')

				if empty
					# Empty Production
					production, _ = self.production(name, '')
					@callback.call(:list, :empty, production)  # FIXME []
				else
					# Single Element Production
					production, _ = self.production(name, list_element_string)
					@callback.call(:list, :single, production)  # FIXME [x]
				end

				# Multiple Element Production
				production, selections = self.production(name, ".#{name} #{separator} .#{list_element_selected_string}")
				@callback.call(:list, :multiple, production, selections) # FIXME xs + [x]

				if build_elements_productions
					# List Element Productions
					list_elements.each do |element|
						production, _ = self.production(list_element_string, element)
						@callback.call(:list, :elements, production) # FIXME x
					end
				end
			end

			name
		end

		# If the production already exists it will be returned.  If it does not
		# exist then it will be created and then returned.
		#
		# @param [Symbol]                         name           The name of the production to add
		# @param [String, Symbol, Array<String>]  list_elements  Expression(s) that may appear in the list
		#
		# @return [void]
		def get_optional_production(name, list_elements)
			if @nonterms.include?(name)
				name

			else
				build_optional_production(name, list_elements)
			end
		end
		alias :get_optional :get_optional_production

		# Build a production for an optional symbol.  This is used to
		# eliminate the EBNF ? operator.
		#
		# @param [Symbol]  name        The name for the new production
		# @param [Symbol]  opt_symbol  Symbol to expand
		#
		# @return [Symbol]  The value of the name argument
		def build_optional_production(name, opt_symbol)
			if not @productions_sym.has_key?(name)
				# Add the items for the following productions:
				#
				# name: | opt_symbol

				# Empty production.
				production = self.add_production(Production.new(self.next_id, name, []))
				@callback.call(:optional, :empty, production)

				# Nonempty production
				production = self.add_production(Production.new(self.next_id, name, [opt_symbol]))
				@callback.call(:optional, :nonempty, production)

				# Add the new symbol to the list of nonterminals.
				@nonterms << name
			end

			name
		end
		alias :optional :build_optional_production

		# Sets the EBNF callback to *callback*.
		#
		# @param [Proc]  callback  A Proc object to be called when EBNF operators are expanded and list productions are added.
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
		# @param [String, Symbol]  expression  The right-hand side of a CFG production.
		#
		# @return [Array(Production, Array<Integer>)]
		def clause(expression)
			raise GrammarError, 'CFG#clause called outside of CFG#production block.' if not @curr_lhs

			lhs        = @curr_lhs.to_sym
			rhs        = Array.new
			tokens     = @lexer.lex(expression.to_s)
			selections = Array.new

			# Set this as the start symbol if there isn't one already
			# defined.
			@start_symbol ||= lhs

			# Remove EBNF tokens and replace them with new productions.
			symbol_count = 0
			tokens.each_index do |i|
				ttype0  = tokens[i].type
				tvalue0 = tokens[i].value

				if ttype0 == :TERM or ttype0 == :NONTERM

					# Add this symbol to the correct collection.
					(ttype0 == :TERM ? @terms : @nonterms) << tvalue0

					rhs <<
					if i + 1 < tokens.length
						case tokens[i + 1].type
						when :QUESTION then self.get_optional_production("#{tvalue0.downcase}_optional".to_sym, tvalue0)
						when :STAR     then self.get_list_production("#{tvalue0.downcase}_list".to_sym, tvalue0)
						when :PLUS     then self.get_nonempty_list_production("#{tvalue0.downcase}_nonempty_list".to_sym, tvalue0)
						else                tvalue0
						end
					else
						tvalue0
					end

					symbol_count += 1

				elsif ttype0 == :DOT
					selections << symbol_count
				end
			end

			# Make the production.
			@production_buffer << [(production = Production.new(self.next_id, lhs, rhs)), selections]

			# Make sure the production symbol is collected.
			@nonterms << lhs

			# Add the new production to our collections.
			self.add_production(production)

			return [production, selections]
		end

		# This function calculates the *first* set of a series of tokens.  It
		# uses the {CFG#first_set} helper function to find the first set of
		# individual symbols.
		#
		# @param [Symbol, Array<Symbol>]  sentence  Sentence to find the *first set* for.
		#
		# @return [Array<Symbol>]  The *first set* for the given sentence.
		def first_set(sentence)
			if sentence.is_a?(Symbol)
				first_set_prime(sentence)

			elsif sentence.all? { |sym| self.symbols.include? sym }
				set0           = []
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
		# @param [Symbol]         sym0           The symbol to find the *first set* of.
		# @param [Array<Symbol>]  seen_lh_sides  Previously seen LHS symbols.
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
		# @param [Symbol]         sym0           The symbol to find the *follow set* for.
		# @param [Array<Symbol>]  seen_lh_sides  Previously seen LHS symbols.
		#
		# @return [Array<Symbol>]
		def follow_set(sym0, seen_lh_sides = [])

			# Use the memoized set if possible.
			return @follows[sym0] if @follows.has_key?(sym0)

			if @nonterms.member? sym0
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

		# @return [Integer]  ID for the next production to be defined.
		def next_id
			@production_counter += 1
		end

		# @return [Set<Symbol>] All terminal symbols used in the grammar's definition.
		def nonterms
			@nonterms.clone
		end

		# Builds a new production with the left-hand side value of *symbol*.
		# If *expression* is specified it is take as the right-hand side of
		# production.  If *expression* is nil then *block* is evaluated, and
		# expected to make one or more calls to {CFG#clause}.
		#
		# @param [Symbol]          symbol      The left-hand side of a production
		# @param [String, Symbol]  expression  The right-hand side of a production
		# @param [Proc]            block       Optional block for defining production clauses
		#
		# @return [Production, Array<Production>]  A single production if called with an expression;
		#   an array of productions otherwise
		def production(symbol, expression = nil, &block)
			@production_buffer = Array.new

			prev_lhs  = @curr_lhs
			@curr_lhs = symbol

			ret_val =
			if expression
				self.clause(expression)
			else
				self.instance_exec(&block)

				@production_buffer.clone
			end

			# Restore the lhs in case it was changed.
			@curr_lhs = prev_lhs
			return ret_val
		end

		# If *by* is :sym, returns a hash of the grammar's productions, using
		# the productions' left-hand side symbol as the key.  If *by* is :id
		# an array of productions is returned in the order of their
		# definition.
		#
		# @param [:sym, :id]  by  The way in which productions should be returned.
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
		# @param [Symbol]  symbol  The new start symbol.
		#
		# @return [Symbol]
		def start(symbol)
			if not CFG::is_nonterminal?(symbol)
				raise GrammarError, 'Start symbol must be a non-terminal.'
			end

			@start_symbol = symbol
		end

		# @return [Array<Symbol>]  All symbols used in the grammar's definition.
		def symbols
			self.terms + self.nonterms
		end

		# @return [Set<Symbol>]  All terminal symbols used in the grammar's definition.
		def terms
			@terms.clone
		end

		# Oddly enough, the Production class represents a production in a
		# context-free grammar.
		class Production
			# @return [Integer]  ID of this production.
			attr_reader :id

			# @return [Symbol]  Left-hand side of this production.
			attr_reader :lhs

			# @return [Array<Symbol>]  Right-hand side of this production.
			attr_reader :rhs

			# Instantiates a new Production object with the specified ID,
			# and left- and right-hand sides.
			#
			# @param [Integer]        id   ID number of this production.
			# @param [Symbol]         lhs  Left-hand side of the production.
			# @param [Array<Symbol>]  rhs  Right-hand side of the production.
			def initialize(id, lhs, rhs)
				@id  = id
				@lhs = lhs
				@rhs = rhs
			end

			# Comparese on production to another.  Returns true only if the
			# left- and right- hand sides match.
			#
			# @param [Production]  other  Another production to compare to.
			#
			# @return [Boolean]
			def ==(other)
				self.lhs == other.lhs and
				self.rhs == other.rhs
			end

			# @return [Production]  A new copy of this production.
			def copy
				Production.new(@id, @lhs, @rhs.clone)
			end

			# @return [Symbol]  The last terminal in the right-hand side of the production.
			def last_terminal
				@rhs.inject(nil) { |m, sym| if CFG::is_terminal?(sym) then sym else m end }
			end

			# @return [Item]  An Item based on this production.
			def to_item
				Item.new(0, @id, @lhs, @rhs)
			end

			# Returns a string representation of this production.
			#
			# @param [Integer]  padding  The ammount of padding spaces to add to the beginning of the string.
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
			# @param [Item]  other  Another item to compare to.
			#
			# @return [Boolean]
			def ==(other)
				self.dot == other.dot and
				self.lhs == other.lhs and
				self.rhs == other.rhs
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
			# @return [Symbol]  Symbol located after the dot (at the index indicated by the {#dot} attribute).
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
