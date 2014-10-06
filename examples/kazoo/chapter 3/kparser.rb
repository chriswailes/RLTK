# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/09
# Description:	This file defines a simple parser for the Kazoo language.

# RLTK Files
require 'rltk/parser'

# Tutorial Files
require './kast'

module Kazoo
	class Parser < RLTK::Parser

		left :PLUS, :SUB
		left :MUL, :DIV

		production(:input, 'statement SEMI') { |s, _| s }

		production(:statement) do
			clause('e')		{ |e| e }
			clause('ex')		{ |e| e }
			clause('p')		{ |p| p }
			clause('f')		{ |f| f }
		end

		production(:e) do
			clause('LPAREN e RPAREN') { |_, e, _| e }

			clause('NUMBER')	{ |n| Number.new(n)   }
			clause('IDENT')	{ |i| Variable.new(i) }

			clause('e PLUS e')	{ |e0, _, e1| Add.new(e0, e1) }
			clause('e SUB e')	{ |e0, _, e1| Sub.new(e0, e1) }
			clause('e MUL e')	{ |e0, _, e1| Mul.new(e0, e1) }
			clause('e DIV e')	{ |e0, _, e1| Div.new(e0, e1) }
			clause('e LT e')	{ |e0, _, e1| LT.new(e0, e1)  }

			clause('IDENT LPAREN args RPAREN') { |i, _, args, _| Call.new(i, args) }
		end

		list(:args, :e, :COMMA)

		production(:ex, 'EXTERN p_body')	{ |_, p| p }
		production(:p, 'DEF p_body')		{ |_, p| p }
		production(:f, 'p e')			{ |p, e| Function.new(p, e) }

		production(:p_body, 'IDENT LPAREN arg_defs RPAREN') { |name, _, arg_names, _| Prototype.new(name, arg_names) }

		list(:arg_defs, :IDENT, :COMMA)

		finalize use: 'kparser.tbl'
	end
end
