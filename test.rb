#!/usr/bin/ruby

require 'parser'

class Tester < RLTK::Parser
	
	rule(:e) do
		clause('e * b') {}
		clause('e + b') {}
		
		clause('b') {}
	end
	
	rule(:b, 'ZERO') {}
	rule(:b, 'ONE' ) {}
	
	finalize
end
