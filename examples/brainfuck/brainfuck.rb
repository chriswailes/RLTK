#!/usr/bin/ruby

############
# Requires #
############

# Standard library requires
require 'pp'

# RLTK requires
require 'rltk/lexer'
require 'rltk/parser'
require 'rltk/ast'
require 'rltk/cg/contractor'
require 'rltk/cg/execution_engine'

# Project requires
require 'bflexer'
require 'bfparser'
require 'bfjit'

########
# Main #
########

jit = Brainfuck::JIT.new

if ARGV[0]
	raise "No such file exists: #{ARGV[0]}" if not File.exists?(ARGV[0])
	
	jit.visit Brainfuck::Parser.parse(Brainfuck::Lexer.lex_file(ARGV[0]))
else
	loop do
		print('Brainfuck: ')
		line = ''
	
		begin
			line += ' ' if not line.empty?
			line += $stdin.gets.chomp
		end while line[-1,1] != ';'
		
		line = line[0..-2]
	
		if line == 'quit;' or line == 'exit;'
			jit.module.verify
			jit.module.dump
		
			break
		end
	
		begin
			tokens = Brainfuck::Lexer.lex(line)
			pp tokens
			
			ast = Brainfuck::Parser.parse(tokens, verbose: true)
			pp ast
			
			jit.visit ast
			
	
		rescue Exception => e
			puts e.message
			puts e.backtrace
			puts
	
		rescue RLTK::LexingError, RLTK::NotInLanguage
			puts 'Line was not in language.'
		end
	end
end
