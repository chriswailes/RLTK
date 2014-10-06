# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/09
# Description:	This file defines a simple lexer for the Kazoo language.

# RLTK Files
require 'rltk/lexer'

module Kazoo
	class Lexer < RLTK::Lexer
		# Skip whitespace.
		rule(/\s/)

		# Keywords
		rule(/def/)	{ :DEF    }
		rule(/extern/)	{ :EXTERN }
		rule(/if/)	{ :IF     }
		rule(/then/)	{ :THEN   }
		rule(/else/)	{ :ELSE   }
		rule(/for/)	{ :FOR    }
		rule(/in/)	{ :IN     }

		# Operators and delimiters.
		rule(/\(/)	{ :LPAREN }
		rule(/\)/)	{ :RPAREN }
		rule(/;/)		{ :SEMI   }
		rule(/,/)		{ :COMMA  }
		rule(/=/)		{ :ASSIGN }
		rule(/\+/)	{ :PLUS   }
		rule(/-/)		{ :SUB    }
		rule(/\*/)	{ :MUL    }
		rule(/\//)	{ :DIV    }
		rule(/</)		{ :LT     }
		rule(/>/)		{ :GT     }
		rule(/!/)		{ :BANG   }
		rule(/\|/)	{ :PIPE   }
		rule(/&/)		{ :AMP    }
		rule(/==/)	{ :EQL    }
		rule(/:/)		{ :SEQ    }

		# Identifier rule.
		rule(/[A-Za-z][A-Za-z0-9]*/) { |t| [:IDENT, t] }

		# Numeric rules.
		rule(/\d+/)		{ |t| [:NUMBER, t.to_f] }
		rule(/\.\d+/)		{ |t| [:NUMBER, t.to_f] }
		rule(/\d+\.\d+/)	{ |t| [:NUMBER, t.to_f] }

		# Comment rules.
		rule(/#/)				{ push_state :comment }
		rule(/\n/, :comment)	{ pop_state }
		rule(/./, :comment)
	end
end
