# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/27
# Description:	This file sets up autoloads for the RLTK module.

module RLTK
	autoload :AST,		'rltk/ast'
	autoload :CFG,		'rltk/cfg'
	autoload :Lexer,	'rltk/lexer'
	autoload :Parser,	'rltk/parser'
	autoload :Token,	'rltk/token'
end
