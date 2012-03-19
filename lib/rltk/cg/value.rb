# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines LLVM Value classes.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Value
		extend RLTK::CG::Bindings::Value
		
		def initialize(ptr)
			if not ptr.is_a?(FFI::Pointer)
				raise 'Argument to new should be of class FFI::Pointer'
			end
			
			if ptr.null?
				raise NullPointerError, 'Trying to create a Value with a null pointer.'
			end
			
			@ptr = ptr
		end
		
		def type
			type_of(@ptr)
		end
	end
	
	class Argument < Value
	end
	
	class Basicblock < Value
	end
	
	class User < Value
	end
	
	class Constant < User
	end
	
	class ConstantArray < Constant
	end
	
	class ConstantExpr < Constant
	end
	
	class ConstantInt < Constant
	end
	
	class ConstantReal < Constant
	end
	
	class Float < ConstantReal
	end
	
	class Double < ConstantReal
	end
	
	class ConstantStruct < Constant
	end
	
	class ConstantVector < Constnat
	end
	
	class GlobalValue < Constant
	end
	
	class Function < GlobalValue
	end
	
	class GlobalAlias < GlobalValue
	end
	
	class GlobalVariable < GlobalValue
	end
	
	class Instruction < User
	end
	
	class CallInst < Instruction
	end
	
	class Phi < Instruction
	end
	
	class SwitchInst < Instruction
	end
end

