#!/usr/bin/ruby

# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/09
# Description:	This file is the driver for the Kazoo tutorial.

# Tutorial Files
require './klexer'
require './kparser'
require './kcontractor'
#require './kjit'

# Load the Kazoo C library.
RLTK::CG::Support.load_library('./libkazoo.so')

# Create our JIT compiler.
jit = Kazoo::Contractor.new
#jit = Kazoo::JIT.new

loop do
	print('Kazoo > ')
	line = ''

	begin
		line += ' ' if not line.empty?
		line += $stdin.gets.chomp
	end while line[-1,1] != ';'

	if line == 'quit;' or line == 'exit;'
		jit.module.verify
		jit.module.dump

		break
	end

	begin
		ast = Kazoo::Parser.parse(Kazoo::Lexer.lex(line))
		ir  = jit.add(ast)

		jit.optimize(ir).dump

		if ast.is_a?(Kazoo::Expression)
			puts "=> #{jit.execute(ir).to_f(RLTK::CG::DoubleType)}"
		end

	rescue Exception => e
		puts e.message
		puts

	rescue RLTK::LexingError, RLTK::NotInLanguage
		puts 'Line was not in language.'
	end
end
