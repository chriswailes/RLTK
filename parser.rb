# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/01/19
# Description:	This file contains the base class for parsers that use RLTK.

############
# Requires #
############

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
				
				def self.finalize
					
					#Remove the reference to the Proxy object so it will be
					#collected.
					@proxy = nil
				end
				
				def self.get_question(token)
					new_token = Token.new(:NONTERM, (token.value.to_s + '_question').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_question: | token
						
						#1st (empty) production.
						@items[new_token.value] << [Token.new(:DOT)]
						
						#2nd production
						@items[new_token.value] << [Token.new(:DOT), token]
						@items[new_token.value] << [token, Token.new(:DOT)]
					end
					
					return new_token
				end
				
				def self.get_plus(token)
					new_token = Token.new(:NONTERM, (token.value.to_s + '_plus').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_plus: token | token token_plus
						
						#1st production
						@items[new_token.value] << [Token.new(:DOT), token]
						@items[new_token.value] << [token, Token.new(:DOT)]
						
						#2nd production
						@items[new_token.value] << [Token.new(:DOT), token, new_token]
						@items[new_token.value] << [token, Token.new(:DOT), new_token]
						@items[new_token.value] << [token, new_token, Token.new(:DOT)]
					end
					
					return new_token
				end
				
				def self.get_star(token)
					new_token = Token.new(:NONTERM, (token.value.to_s + '_star').to_sym)
					
					if not @items.has_key?(new_token.value)
						#Add the items for the following productions:
						#
						#token_star: | token token_star
						
						#1st (empty) production
						@items[new_token.value] << [Token.new(:DOT)]
						
						#2nd production
						@items[new_token.value] << [Token.new(:DOT), token, new_token]
						@items[new_token.value] << [token, Token.new(:DOT), new_token]
						@items[new_token.value] << [token, new_token, Token.new(:DOT)]
					end
					
					return new_token
				end
				
				def self.rule(symbol, expression = nil, &action)
					#Set the start symbol if this is the first production
					#defined.
					@start_state ||= symbol
					
					items[symbol] += if expression then @proxy.clause(expression, &action) else @proxy.wrapper(&action) end
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
			attr_reader :item
			attr_reader :action
			
			def initialize(item, action)
				@item	= item
				@action	= action
			end
		end
		
		class RuleProxy
			def initialize(parser)
				@parser = parser
				
				@lexer = EBNFLexer.new
				@items = Array.new
			end
			
			def clause(expression, &action)
				clause_items = Array.new
				tokens = @lexer.lex(expression)
				
				#Remove EBNF tokens and replace them with new productions.
				new_tokens = Array.new
				
				tokens.each_index do |i|
					ttype0 = tokens[i].type
					
					if ttype0 == :TERM or ttype0 == :NONTERM
						if i + 1 < tokens.length
							ttype1 = tokens[i + 1].type
							
							new_tokens <<
							case tokens[i + 1].type
								when :'?'
									@parser.get_question(tokens[i].value)
								
								when :*
									@parser.get_star(tokens[i].value)
								
								when :+
									@parser.get_plus(tokens[i].value)
								
								else
									tokens[i]
							end
						else
							new_tokens << tokens[i]
						end
					end
				end
				
				tokens = new_tokens
				
				#Create the items for this clause.
				(1...tokens.length).each do |i|
					clause_items << Array.new(tokens).insert(i, Token.new(:DOT))
				end
				
				#Add the items to the current list.
				@items += clause_items
				
				#Return the items from just this clause.
				return clause_items
			end
			
			def wrapper(&block)
				@items = Array.new
				
				self.instance_exec(&block)
				
				return @items
			end
		end
	end
end
