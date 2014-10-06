# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains a parser for a simple postfix calculator.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/parser'

#######################
# Classes and Modules #
#######################

module RLTK
	module Parsers

		# A parser for a simple post-fix calculator.
		class PostfixCalc < Parser
			production(:e) do
				clause('NUM') { |n| n }

				clause('e e PLS') { |e0, e1, _| e0 + e1 }
				clause('e e SUB') { |e0, e1, _| e0 - e1 }
				clause('e e MUL') { |e0, e1, _| e0 * e1 }
				clause('e e DIV') { |e0, e1, _| e0 / e1 }
			end

			finalize
		end
	end
end
