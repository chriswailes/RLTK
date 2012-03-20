# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/15
# Description:	This file defines the LLVM module.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/version'
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	module LLVM
		def self.init(arch)
			if Bindings::ARCHS.include?(arch)
				arch = Bindings.get_bname(arch)
				
				Bindings.send("initialize_#{arch}_target".to_sym)
				Bindings.send("initialize_#{arch}_target_info".to_sym)
				Bindings.send("initialize_#{arch}_target_mc".to_sym)
			
				true
			
			else
				raise "Unsupported architecture specified: #{arch}"
			end
		end
	
		def self.version
			RLTK::LLVM_TARGET_VERSION
		end
	end
end
