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
	class ParsingError < Exception; end
	
	class Parser
		def Parser.inherited(klass)
			klass.class_exec do
				@items = Hash.new {|h, k| h[k] = Array.new}
				@proxy = RuleProxy.new(self)
				
				#################
				# Class Methods #
				#################
				
				def self.close_set(set)
					set.items.each do |item|
						next_token = item.next_token
						
						if next_token and next_token.type == :NONTERM
							set.append(@items[next_token.value])
						end
					end
					
					return set
				end
				
				def self.finalize
					#Remove the reference to the Proxy object so it will be
					#collected.
					@proxy = nil
					
					#Create our Transition Table
					@table = Table.new
					
					#Add our starting state to the transition table.
					set = Set.new([Item.new([Token.new(:DOT), Token.new(:NONTERM, @start_state)])])
					@table.add_set(self.close_set(set))
					
					#Build the rest of the transition table.
					@table.rows.each do |row|
						cur_set = row.set
						
						#Transition Sets
						tsets = Hash.new {|h,k| h[k] = Set.new}
						
						#Bin each item in this set into reachable
						#transition sets.
						cur_set.items.each do |item|
							if (next_token = item.next_token)
								tsets[next_token.value] << item.copy
							end
						end
						
						#For each transition set:
						# 1) Get transition token
						# 2) Advance dot
						# 3) Close it
						# 4) Get state id, and add transition
						tsets.each do |ttoken, tset|
							tset.items.each {|item| item.advance}
							
							tset = close_set(tset)
							
							id = @table.get_set_id(tset)
							
							row.on(ttoken, id)
						end
					end
				end
				
				def self.get_question(token)
					new_token = Token.new(:NONTERM, ('!' + token.value.to_s + '_question').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_question: | token
						
						#1st (empty) production.
						@items[new_token.value] << Item.new([Token.new(:DOT)]) { nil }
						
						#2nd production
						@items[new_token.value] << Item.new([Token.new(:DOT), token]) {|v| v[0]}
						@items[new_token.value] << Item.new([token, Token.new(:DOT)]) {|v| v[0]}
					end
					
					return new_token
				end
				
				def self.get_plus(token)
					new_token = Token.new(:NONTERM, ('!' + token.value.to_s + '_plus').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_plus: token | token token_plus
						
						#1st production
						@items[new_token.value] << Item.new([Token.new(:DOT), token]) {|v| [v[0]]}
						@items[new_token.value] << Item.new([token, Token.new(:DOT)]) {|v| [v[0]]}
						
						#2nd production
						@items[new_token.value] << Item.new([Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
						@items[new_token.value] << Item.new([token, Token.new(:DOT), new_token]) {|v| [v[0]] + v[1]}
						@items[new_token.value] << Item.new([token, new_token, Token.new(:DOT)]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.get_star(token)
					new_token = Token.new(:NONTERM, ('!' + token.value.to_s + '_star').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_star: | token token_star
						
						#1st (empty) production
						@items[new_token.value] << Item.new([Token.new(:DOT)]) { [] }
						
						#2nd production
						@items[new_token.value] << Item.new([Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
						@items[new_token.value] << Item.new([token, Token.new(:DOT), new_token]) {|v| [v[0]] + v[1]}
						@items[new_token.value] << Item.new([token, new_token, Token.new(:DOT)]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.rule(symbol, expression = nil, &action)
					#Set the start symbol if this is the first production
					#defined.
					@start_state ||= symbol
					
					symbol = symbol.to_sym if not symbol.is_a?(Symbol)
					
					if expression
						@items[symbol] << @proxy.clause(expression, &action)
					else
						@items[symbol] += @proxy.wrapper(&action)
					end
				end
				
				def self.start(state)
					@start_state = state
				end
				
				####################
				# Instance Methods #
				####################
				
				def parse(tokens)
					stacks = Array.new
					#FIXME
				end
			end
		end
		
		class Item
			attr_reader :tokens
			attr_reader :action
			
			def initialize(tokens, &action)
				@tokens	= tokens
				@action	= action || Proc.new {}
			end
			
			def ==(other)
				self.action == other.action and self.tokens == other.tokens
			end
			
			def advance
				index = @tokens.index {|t| t.type == :DOT}
				
				if index < @tokens.length - 1
					@tokens[index], @tokens[index + 1] = @tokens[index + 1], @tokens[index]
				end
			end
			
			def copy
				return Item.new(@tokens.clone, &@action.clone)
			end
			
			def next_token
				next_token = nil
				
				@tokens.each_index do |i|
					if @tokens[i].type == :DOT
						next_token = @tokens[i + 1]
						break
					end
				end
				
				return next_token
			end
		end
		
		class RuleProxy
			def initialize(parser)
				@parser = parser
				
				@lexer = EBNFLexer.new
				@items = Array.new
			end
			
			def clause(expression, &action)
				tokens = @lexer.lex(expression)
				
				#Remove EBNF tokens and replace them with new productions.
				new_tokens = [Token.new(:DOT)]
				
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
				
				#Add the item to the current list.
				@items << (item = Item.new(new_tokens))
				
				#Return the item from this clause.
				return item
			end
			
			def wrapper(&block)
				@items = Array.new
				
				self.instance_exec(&block)
				
				return @items
			end
		end
		
		class Set
			attr_reader :id
			attr_reader :items
			
			def initialize(items = [])
				@items	= items
			end
			
			def ==(other)
				self.items == other.items
			end
			
			def <<(item)
				if not @items.include?(item) then @items << item end
			end
			
			def append(items)
				items.each { |item| self << item }
			end
		end
		
		class Table
			attr_reader :rows
			
			def initialize
				@id_counter	= -1
				@rows		= Array.new
			end
			
			def add_set(set)
				@rows << Row.new((@id_counter += 1), set)
				
				return @id_counter
			end
			
			def get_set_id(set)
				id = nil
				
				@rows.each {|row| if row.set == set then id = row.id; break end}
				
				if id then id else self.add_set(set) end
			end
			
			class Row
				attr_reader :id
				attr_reader :set
				
				def initialize(id, set)
					@id			= id
					@set			= set
					@transitions	= Hash.new
				end
				
				def on(symbol, id)
					@transitions[symbol] = id
				end
			end
		end
	end
end
