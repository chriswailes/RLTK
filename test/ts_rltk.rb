# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains the test suit for RLTK.  It requires the
#			individual tests from their respective files.

############
# Requires #
############

# Filigree
require 'filigree/request_file'

request_file('simplecov', 'SimpleCov is not installed.') do
	SimpleCov.start do
		add_filter 'tc_*'
		add_filter 'generated*'
	end
end

# Gems
require 'ffi'

# Ruby Language Toolkit
require 'rltk/version'

# Test cases
require 'tc_token'
require 'tc_ast'
require 'tc_cfg'
require 'tc_lexer'
require 'tc_parser'
require 'tc_visitor'

require 'util/ts_util'

#begin
#	# Check to make sure the target LLVM library is present.
#	class Tester
#		extend FFI::Library
#		
#		ffi_lib("LLVM-#{RLTK::LLVM_TARGET_VERSION}")
#	end
#	
#	# The test suite for the LLVM bindings
#	require 'cg/ts_cg'
#rescue
#end
