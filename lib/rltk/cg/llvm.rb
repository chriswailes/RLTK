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

module RLTK::CG::LLVM
	include RLTK::CG::Bindings::LLVM
	
	# Pull the ARCHS constant from the Bindings::LLVM module.
	ARCHS = RLTK::CG::Bindings::LLVM::ARCHS
	
	def self.init(arch)
		if ARCHS.include?(arch)
			self.send("initialize_#{arch.to_s.downcase}_target".to_sym)
			self.send("initialize_#{arch.to_s.downcase}_target_info".to_sym)
			self.send("initialize_#{arch.to_s.downcase}_target_mc".to_sym)
			
			true
			
		else
			raise "Unsupported architecture specified: #{arch}"
		end
	end
	
	def self.version
		RLTK::LLVM_TARGET_VERSION
	end
end
