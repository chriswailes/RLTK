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
				@rules = Hash.new {|h, k| h[k] = Array.new}
				@proxy = RuleProxy.new(self)
				
				#################
				# Class Methods #
				#################
				
				def self.close_set(set)
					set.rules.each do |rule|
						next_token = rule.next_token
						
						if next_token and next_token.type == :NONTERM
							set.append(@rules[next_token.value])
						end
					end
					
					return set
				end
				
				def self.dump(table_file)
					if @rules
						File.open(table_file, 'w') do |f|
							f.puts("Start symbol: #{@start_symbol}")
							f.puts
							
							f.puts("Rules for #{self.class.name}:")
							
							#Print the rules.
							@rules.each_key do |sym|
								@rules[sym].each do |rule|
									f.puts("\t" + rule.to_s)
								end
								
								f.puts
							end
							
							#Print the parse table.
							f.puts("Parse Table:")
							@table.rows.each do |row|
								f.puts("Row #{row.id}:")
								
								row.set.each do |item|
									
								end
							end
						end
					else
						File.open(table_file, 'w') {|f| f.puts('Parser.dump called outside of finalize.')}
					end
				end
				
				def self.finalize(table_file = nil)
					#Create our Transition Table
					@table	= Table.new
					
					#pp @rules.values.flatten
					
					@actions	= @rules.values.flatten.inject([]) {|a, r| a[r.id] = r.action; a}
					
					#Add our starting set to the transition table.
					start_rule = Rule.new(0, :'!start', [Token.new(:DOT), Token.new(:NONTERM, @start_symbol), Token.new(:TERM, :EOF)])
					start_set = self.close_set(Set.new([start_rule]))
					@table.add_set(start_set)
					
					#Build the rest of the transition table.
					@table.rows.each do |row|
						#Transition Sets
						tsets = Hash.new {|h,k| h[k] = Set.new}
						
						#Bin each item in this set into reachable
						#transition sets.
						row.set.each do |rule|
							if (next_token = rule.next_token)
								tsets[[next_token.type, next_token.value]] << rule.copy
							end
						end
						
						#For each transition set:
						# 1) Get transition token
						# 2) Advance dot
						# 3) Close it
						# 4) Get state id, and add transition
						tsets.each do |ttoken, tset|
							ttype, tsym = ttoken
							
							tset.rules.each {|rule| rule.advance}
							
							tset = close_set(tset)
							
							id = @table.get_set_id(tset)
							
							#Add Goto, Accept, and Shift actions.
							if ttype == :NONTERM
								row.on(ttoken, Table::GoTo.new(id))
							elsif tsym == :EOF
								row.on(ttoken, Table::Accept.new)
							else
								row.on(ttoken, Table::Shift.new(id))
							end
						end
						
						#Find the Reduce actions for this set.
						row.rules.each do |rule|
							if rule.tokens[-1].type == :DOT
								row.on(nil, Table::Reduce.new(rule.id))
							end
						end
					end
					
					#Print the table if requested.
					self.dump(table_file) if table_file
					
					#Remove references to the RuleProxy and Item list.
					@proxy = @rules = nil
					
					#Drop the sets from the table.
					@table.drop_sets
				end
				
				def self.get_question(token)
					new_symbol	= ('!' + token.value.to_s + '_question').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_question: | token
						
						#1st (empty) production.
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) { nil }
						
						#2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|v| v[0]}
					end
					
					return new_token
				end
				
				def self.get_plus(token)
					new_symbol	= ('!' + token.value.to_s + '_plus').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_plus: token | token token_plus
						
						#1st production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token]) {|v| [v[0]]}
						
						#2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.get_star(token)
					new_symbol	= ('!' + token.value.to_s + '_star').to_sym
					new_token		= Token.new(:NONTERM, new_symbol)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_star: | token token_star
						
						#1st (empty) production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT)]) { [] }
						
						#2nd production
						@items[new_symbol] << Rule.new(@proxy.next_id, new_symbol, [Token.new(:DOT), token, new_token]) {|v| [v[0]] + v[1]}
					end
					
					return new_token
				end
				
				def self.rule(symbol, expression = nil, &action)
					#Convert the 'symbol' to a Symbol if it isn't already.
					symbol = symbol.to_sym if not symbol.is_a?(Symbol)
					
					#Set the start symbol if this is the first production
					#defined.
					@start_symbol ||= symbol
					
					#Set the symbol in the RuleProxy.
					@proxy.symbol = symbol
					
					if expression
						@rules[symbol] << @proxy.clause(expression, &action)
					else
						@rules[symbol] += @proxy.wrapper(&action)
					end
				end
				
				def self.start(symbol)
					@start_symbol = symbol
				end
				
				####################
				# Instance Methods #
				####################
				
				def parse(tokens)
					#Start out with one stack in state zero.
					stacks = [[0]]
					
					tokens.each do |token|
						new_stacks = []
						
						stacks.each do |stack|
							actions = @table[stack.last].on?(token)
							
							if actions.length == 0
								stacks.delete(stack)
									
								#Check to see if we removed the last stack.
								if stacks.length == 0
									raise ParsingError, 'Out of actions.'
								end
							else
								actions.each do |action|
									new_stacks << (new_stack = stack.clone)
									
									case action.class
										when Accept
											
										
										when Reduce
											
										
										when Shift
											new_stack << action.id
									end
								end
							end
						end
						
						stacks = new_stacks
					end
				end
			end
		end
		
		class Rule
			attr_reader :id
			attr_reader :symbol
			attr_reader :tokens
			attr_reader :action
			
			attr_reader :next_token
			
			def initialize(id, symbol, tokens, &action)
				@id		= id
				@symbol	= symbol
				@tokens	= tokens
				@action	= action || Proc.new {}
				
				@next_token = @tokens[self.dot_index + 1]
			end
			
			def ==(other)
				self.action == other.action and self.tokens == other.tokens
			end
			
			def advance
				if (index = self.dot_index) < @tokens.length - 1
					@tokens[index], @tokens[index + 1] = @tokens[index + 1], @tokens[index]
					@next_token = @tokens[index + 1]
				end
			end
			
			def copy
				Rule.new(@id, @symbol, @tokens.clone, &@action)
			end
			
			def dot_index
				@tokens.index {|t| t.type == :DOT}
			end
			
			def to_s
				"#{@symbol} -> #{@tokens.map{|t| t.value}.join(' ')}"
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
				@rules << (rule = Rule.new(self.next_id, @symbol, new_tokens, &action))
				
				#Return the item from this clause.
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
		
		class Set
			attr_reader :rules
			
			def initialize(rules = [])
				@rules = rules
			end
			
			def ==(other)
				self.rules == other.rules
			end
			
			def <<(rule)
				if not @rules.include?(rule) then @rules << rule end
			end
			
			def append(new_rules)
				new_rules.each {|rule| self << rule}
			end
			
			def each
				@rules.each {|r| yield r}
			end
		end
		
		class Table
			attr_reader :rows
			
			def initialize
				@id_counter	= -1
				@rows		= Array.new
			end
			
			def [](index)
				@rows[index]
			end
			
			def add_set(set)
				@rows << Row.new((@id_counter += 1), set)
				
				return @id_counter
			end
			
			def drop_sets
				@rows.each {|row| row.drop_set}
			end
			
			def get_set_id(set)
				id = nil
				
				@rows.each {|row| if row.set == set then id = row.id; break end}
				
				if id then id else self.add_set(set) end
			end
			
			class Row
				attr_reader :id
				attr_accessor :set
				
				def initialize(id, set)
					@id		= id
					@set		= set
					@actions	= Hash.new {|h,k| h[k] = Array.new}
				end
				
				def drop_set
					@set = nil
				end
				
				def on(symbol, action)
					@actions[symbol] << action
				end
				
				def on?(symbol)
					@actions[nil] | @actions[symbol]
				end
				
				def rules
					@set.rules
				end
			end
			
			class Action
				attr_reader :id
				
				def initialize(id = nil)
					@id = id
				end
			end
			
			class Accept	< Action; end
			class GoTo	< Action; end
			class Reduce	< Action; end
			class Shift	< Action; end
		end
	end
end
