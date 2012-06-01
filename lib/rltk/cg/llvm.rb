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

module RLTK::CG # :nodoc:
	
	# This module contains global operations on the LLVM compiler infrastructure.
	module LLVM
		# Initialize LLVM to generate code for a given architecture.
		#
		# @see Bindings::ARCHS
		#
		# @param [Symbol] arch Architecture to initialize LLVM for.
		#
		# @raise [RuntimeError] An error is raised if an unsupported architecture is specified.
		#
		# @return [true]
		def self.init(arch)
			if Bindings::ARCHS.include?(arch) or Bindings::ARCHS.map { |sym| sym.to_s.downcase.to_sym }.include?(arch)
				arch = Bindings.get_bname(arch)
				
				Bindings.send("initialize_#{arch}_target".to_sym)
				Bindings.send("initialize_#{arch}_target_info".to_sym)
				Bindings.send("initialize_#{arch}_target_mc".to_sym)
			
				true
			
			else
				raise "Unsupported architecture specified: #{arch}"
			end
		end
		
		# @return [String] String representing the version of LLVM targeted by these bindings.
		def self.version
			RLTK::LLVM_TARGET_VERSION
		end
	end
end
