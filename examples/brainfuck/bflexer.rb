############
# Requires #
############

# RLTK requires
require 'rltk/lexer'

module Brainfuck
	class Lexer < RLTK::Lexer
		r(/>/)	{ :PTRRIGHT }
		r(/</)	{ :PTRLEFT  }
		r(/\+/)	{ :INC      }
		r(/-/)	{ :DEC      }
		r(/\./)	{ :PUT      }
		r(/,/)	{ :GET      }
		r(/\[/)	{ :LBRACKET }
		r(/\]/)	{ :RBRACKET }

		r /[^\[\]\-+,.<>]/
	end
end
