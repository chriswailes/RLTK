#!/usr/bin/ruby

require 'pp'

require 'rltk/lexer'
require 'rltk/parser'

#class LALexer < RLTK::Lexer
#	rule(/A/) { [:A, 1] }
#	rule(/B/) { [:B, 2] }
#	rule(/C/)	{ [:C, 3] }
#	
#	rule(/\s/)
#end

#class LAParser < RLTK::Parser
#	production(:s) do
#		clause("A G D") { |_, _, _| }
#		
#		clause("A a C") { |_, _, _| }
#		
#		clause("B a D") { |_, _, _| }
#		
#		clause("B G C") { |_, _, _| }
#	end
#	
#	production(:a, 'b') { |_| }
#	
#	production(:b, 'G') { |_| }
#	
#	finalize
#end

#lexer = LALexer.new
#parser = LAParser.new

class ABLongest < RLTK::Lexer
	rule(/a+/)	{ :APLUS }
	rule(/b+/)	{ :BPLUS }
	
	rule(/a+b+/)	{ :APLUSBPLUS }
end

class ABFirst < RLTK::Lexer
	match_first
	
	rule(/a+/)	{ :APLUS }
	rule(/b+/)	{ :BPLUS }
	
	rule(/a+b+/)	{ :APLUSBPLUS }
end

pp ABFirst.lex('aaabbb')
