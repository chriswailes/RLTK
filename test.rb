#!/usr/bin/ruby

require 'pp'

require 'lexer'
require 'parser'

#~require 'lexers/calculator'
#~require 'parsers/calculator'
#~
#~lexer = RLTK::Lexers::Calc.new
#~parser = RLTK::Parsers::Calc.new

class ABLexer < RLTK::Lexer
	rule(/A/) { [:A, 1] }
	rule(/B/) { [:B, 2] }
	
	rule(/\s/)
end

class ABParser < RLTK::Parser
	
	rule(:a, "A+ B") {|a, b| "Accepted!" }
	
	finalize('tester.table')
end

lexer = ABLexer.new
parser = ABParser.new

pp parser.parse lexer.lex(ARGV[0])
