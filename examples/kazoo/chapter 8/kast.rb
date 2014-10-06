# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/05/09
# Description:	This file defines a simple AST for the Kazoo language.

# RLTK Files
require 'rltk/ast'

module Kazoo

	class Expression < RLTK::ASTNode; end

	class Number < Expression
		value :value, Float
	end

	class Variable < Expression
		value :name, String
	end

	class Assign < Expression
		value :name, String

		child :right, Expression
	end

	class Unary < Expression
		child :operand, Expression
	end

	class Not < Unary; end
	class Neg < Unary; end

	class Binary < Expression
		child :left,	Expression
		child :right,	Expression
	end

	class Add < Binary; end
	class Sub < Binary; end
	class Mul < Binary; end
	class Div < Binary; end
	class LT  < Binary; end
	class GT  < Binary; end
	class Eql < Binary; end
	class Or  < Binary; end
	class And < Binary; end

	class Call < Expression
		value :name, String

		child :args, [Expression]
	end

	class If < Expression
		child :cond, Expression
		child :then, Expression
		child :else, Expression
	end

	class For < Expression
		value :var, String

		child :init, Expression
		child :cond, Expression
		child :step, Expression
		child :body, Expression
	end

	class Prototype < RLTK::ASTNode
		value :name,		String
		value :arg_names,	[String]
	end

	class Function < RLTK::ASTNode
		child :proto,	Prototype
		child :body,	Expression
	end
end
