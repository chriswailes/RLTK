#!/usr/bin/ruby

require 'pp'

require 'rltk/lexer'
require 'rltk/parser'

require 'rltk/lexers/calculator'
require 'rltk/parsers/calculator'

lexer = RLTK::Lexers::Calc.new
parser = RLTK::Parsers::Calc.new

#~class ABLexer < RLTK::Lexer
	#~rule(/A/) { [:A, 1] }
	#~rule(/B/) { [:B, 2] }
	#~
	#~rule(/\s/)
#~end
#~
#~class ABParser < RLTK::Parser
	#~
	#~production(:a, "A* B") {|a, b| "Accepted with #{a.length} A(s)" }
	#~
	#~finalize('tester.table')
#~end
#~
#~lexer = ABLexer.new
#~parser = ABParser.new

#~class LALexer < RLTK::Lexer
	#~rule(/A/) { [:A, 1] }
	#~rule(/B/) { [:B, 2] }
	#~rule(/C/)	{ [:C, 3] }
	#~
	#~rule(/\s/)
#~end
#~
#~class LAParser < RLTK::Parser
	#~production(:s) do
		#~clause("A G D") { |_, _, _| }
		#~
		#~clause("A a C") { |_, _, _| }
		#~
		#~clause("B a D") { |_, _, _| }
		#~
		#~clause("B G C") { |_, _, _| }
	#~end
	#~
	#~production(:a, 'b') { |_| }
	#~
	#~production(:b, 'G') { |_| }
	#~
	#~finalize('lookahead.table')
#~end
#~
#~lexer = LALexer.new
#~parser = LAParser.new

puts parser.parse(lexer.lex(ARGV[0]), if ARGV[1] then (ARGV[1] == 'true') ? true : ARGV[1] end)
