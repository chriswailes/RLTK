############
# Requires #
############

# RLTK requires
require 'rltk/parser'
require 'rltk/ast'

module Brainfuck
	class Operation < RLTK::ASTNode; end
	
	class PtrRight  < Operation; end
	class PtrLeft   < Operation; end
	class Increment < Operation; end
	class Decrement < Operation; end
	class Put       < Operation; end
	class Get       < Operation; end
	
	class Loop < Operation
		child :body, [Operation]
	end
	
	class Program < RLTK::ASTNode
		child :body, [Operation]
	end
	
	class Parser < RLTK::Parser
		
		p(:program, 'op+') { |ops| Program.new(ops) }
		
		p :op do
			c('PTRRIGHT')				{ |_| PtrRight.new          }
			c('PTRLEFT')				{ |_| PtrLeft.new           }
			c('INC')					{ |_| Increment.new         }
			c('DEC')					{ |_| Decrement.new         }
			c('PUT')					{ |_| Put.new               }
			c('GET')					{ |_| Get.new               }
			c('LBRACKET op+ RBRACKET')	{ |_, ops, _| Loop.new(ops) }
		end
		
		finalize use: 'braunfuck.tbl'
	end
end
