#!/usr/bin/ruby

require 'pp'

require 'lexer'
require 'parser'

require 'lexers/calculator'
require 'parsers/calculator'

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
	#~rule(:a, "A* B") {|a, b| "Accepted with #{a.length} A(s)" }
	#~
	#~finalize('tester.table')
#~end
#~
#~lexer = ABLexer.new
#~parser = ABParser.new

puts parser.parse(lexer.lex(ARGV[0]), if ARGV[1] then (ARGV[1] == 'true') ? true : ARGV[1] end)
