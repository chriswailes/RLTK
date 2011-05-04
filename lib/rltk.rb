# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/27
# Description:	This file sets up autoloads for the RLTK module.

# The RLTK module provides a collection of useful tools for dealing with
# context-free grammars.  This includes a class for representing CFGs as well as
# lexer and parser generators.
module RLTK
	autoload :AST,		'rltk/ast'
	autoload :CFG,		'rltk/cfg'
	autoload :Lexer,	'rltk/lexer'
	autoload :Parser,	'rltk/parser'
	autoload :Token,	'rltk/token'
end
