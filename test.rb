#!/usr/bin/ruby

require 'pp'

require 'parser'

class Tester < RLTK::Parser
	
	rule(:e) do
		clause('e MUL b') {}
		clause('e PLUS b') {}
		
		clause('b') {}
	end
	
	rule(:b, 'ZERO') {}
	rule(:b, 'ONE' ) {}
	
	finalize('tester-table.txt')
end
