#!/usr/bin/ruby

# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/09
# Description:	This file is the driver for the Kazoo tutorial.

# Tutorial Files
require './klexer'
require './kparser'

loop do
	print('Kazoo > ')
	line = ''

	begin
		line += ' ' if not line.empty?
		line += $stdin.gets.chomp
	end while line[-1,1] != ';'

	break if line == 'quit;' or line == 'exit;'

	begin
		ast = Kazoo::Parser.parse(Kazoo::Lexer.lex(line))

		case ast
		when Kazoo::Expression	then puts 'Parsed an expression.'
		when Kazoo::Function	then puts 'Parsed a function definition.'
		when Kazoo::Prototype	then puts 'Parsed a prototype or extern definition.'
		end

	rescue RLTK::LexingError, RLTK::NotInLanguage
		puts 'Line was not in language.'
	end
end
