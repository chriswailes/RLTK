# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/24
# Description:	This file contains the a class representing a context-free
#			grammar.

############
# Requires #
############

# Ruby Language Toolkit
require 'lexers/ebnf'

#######################
# Classes and Modules #
#######################

module RLTK
	
	class GrammarError < Exception; end
	
	class CFG
		attr_reader :start_symbol
		
		attr_accessor :curr_lhs
		
		#################
		# Class Methods #
		#################
		
		def self.is_terminal?(sym)
			sym and (s = sym.to_s) == s.upcase
		end
		
		def self.is_nonterminal?(sym)
			sym and (s = sym.to_s) == s.downcase
		end
		
		####################
		# Instance Methods #
		####################
		
		def initialize(&callback)
			@curr_lhs			= nil
			@callback			= callback || Proc.new {}
			@lexer			= Lexers::EBNFLexer.new
			@rule_counter		= -1
			@start_symbol		= nil
			@wrapper_symbol	= nil
			
			@rules_id		= Hash.new
			@rules_sym	= Hash.new { |h, k| h[k] = [] }
			@rule_buffer	= Array.new
			
			@terms	= Hash.new(false).update({:EOS => true})
			@nonterms	= Hash.new(false)
			
			@firsts	= Hash.new
			@follows	= Hash.new
		end
		
		def add_rule(rule)
			@rules_sym[rule.lhs] << (@rules_id[rule.id] = rule)
		end
		
		def callback(&callback)
			@callback = callback || Proc.new {}
		end
		
		def clause(expression)
			
			if not @curr_lhs
				raise GrammarError, 'CFG.clause called outside of CFG.rule block.'
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
			
			# Make the rule.
			@rule_buffer << (rule = Rule.new(self.next_id, lhs, rhs))
			
			# Make sure the production symbol is collected.
			@nonterms[lhs] = true
			
			# Add the new rule to our collections.
			self.add_rule(rule)
			
			return rule
		end
		
		def first_set(sym0)
			
			# Memoize the result for later.
			@firsts[sym0] ||=
			
			if self.symbols.include?(sym0)
				if CFG::is_terminal?(sym0)
					# If the symbol is a terminal, it is the only symbol in
					# its follow set.
					[sym0]
				else
					set = []
					
					@rules_sym[sym0].each do |rule|
						if rule.rhs == []
							# If this is an empty production we should
							# add the empty string to the First set.
							set0 << :'ɛ'
						else
							all_have_emtpy = true
							
							rule.rhs.each do |sym1|
								
								# Grab the First set for the current
								# symbol in this production.
								set0 |= (set1 = self.first_set(sym1)) - [:'ɛ']
								
								if not set1.include?(:'ɛ')
									all_have_empty = false
									break
								end
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
		
		def follow_set(sym0)
			
			#~puts "Building follow set for #{sym0}"
			
			# Memoize the result for later.
			@follows[sym0] ||=
			
			if @nonterms[sym0]
				
				set0 = []
				
				# Add EOS to the start symbol's follow set.
				set0 << :EOS if sym0 == @start_symbol
				
				@rules_id.values.each do |rule|
					rule.rhs.each_cons(2) do |sym1, sym2|
						if sym0 == sym1
							set0 |= (set1 = self.first_set(sym2)) - [:'ɛ']
							
							if set1.include?('ɛ')
								set0 |= self.follow_set(rule.lhs)
							end
						end
					end
					
					if rule.lhs != sym0 and rule.rhs.last == sym0
						set0 |= self.follow_set(rule.lhs) 
					end
				end
				
				set0
			else
				[]
			end
		end
		
		def get_question(symbol)
			new_symbol = (symbol.to_s.downcase + '_question').to_sym
			
			if not @rules_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# nonterm_question: | nonterm
				
				# 1st (empty) production.
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, []))
				@callback.call(rule, :'?', :first)
				
				# 2nd production
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, [symbol]))
				@callback.call(rule, :'?', :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		def get_plus(symbol)
			new_symbol = (symbol.to_s.downcase + '_plus').to_sym
			
			if not @rules_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_plus: token | token token_plus
				
				# 1st production
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, [symbol]))
				@callback.call(rule, :+, :first)
				
				# 2nd production
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, [symbol, new_symbol]))
				@callback.call(rule, :+, :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		def get_star(symbol)
			new_symbol = (symbol.to_s.downcase + '_star').to_sym
			
			if not @rules_sym.has_key?(new_symbol)
				# Add the items for the following productions:
				#
				# token_star: | token token_star
				
				# 1st (empty) production
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, []))
				@callback.call(rule, :*, :first)
				
				# 2nd production
				self.add_rule(rule = Rule.new(self.next_id, new_symbol, [symbol, new_symbol]))
				@callback.call(rule, :*, :second)
				
				# Add the new symbol to the list of nonterminals.
				@nonterms[new_symbol] = true
			end
			
			return new_symbol
		end
		
		def next_id
			@rule_counter += 1
		end
		
		def nonterms
			@nonterms.keys
		end
		
		def rule(symbol, expression = nil, &block)
			@rule_buffer = Array.new
			@curr_lhs = symbol
			
			if expression
				self.clause(expression)
			else
				self.instance_exec(&block)
			end
			
			@curr_lhs = nil
			return @rule_buffer.clone
		end
		
		def rules(by = :sym)
			if by == :sym
				@rules_sym
			elsif by == :id
				@rules_id
			else
				nil
			end
		end
		
		def start(symbol)
			if not CFG::is_nonterminal?(symbol)
				raise ParserConstructionError, 'Start symbol must be a non-terminal.'
			end
			
			@start_symbol = symbol
		end
		
		def symbols
			self.terms + self.nonterms
		end
		
		def terms
			@terms.keys
		end
		
		class Rule
			attr_reader :id
			attr_reader :lhs
			attr_reader :rhs
			
			attr_accessor :prec
			
			def initialize(id, lhs, rhs)
				@id	= id
				@lhs	= lhs
				@rhs	= rhs
			end
			
			def ==(other)
				self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			def copy
				Rule.new(@id, @lhs, @rhs.clone)
			end
			
			def last_terminal
				@rhs.inject(nil) { |m, sym| if CFG::is_terminal?(sym) then sym else m end }
			end
			
			def to_item
				Item.new(0, @id, @lhs, @rhs)
			end
			
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.map { |s| s.to_s }.join(' ')}"
			end
		end
		
		class Item < Rule
			attr_reader :dot
			
			def initialize(dot, *args)
				super(*args)
				
				# The Dot indicates the NEXT symbol to be read.
				@dot = dot
			end
			
			def ==(other)
				self.dot == other.dot and self.lhs == other.lhs and self.rhs == other.rhs
			end
			
			def advance
				if @dot < @rhs.length
					@dot += 1
				end
			end
			
			def at_end
				@dot == @rhs.length
			end
			
			def copy
				Item.new(@dot, @id, @lhs, @rhs.clone)
			end
			
			def next_symbol
				@rhs[@dot]
			end
			
			def to_s(padding = 0)
				"#{format("%-#{padding}s", @lhs)} -> #{@rhs.map { |s| s.to_s }.insert(@dot, '·').join(' ') }"
			end
		end
	end
end
