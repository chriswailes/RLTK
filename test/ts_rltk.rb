# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains the test suit for RLTK.  It requires the
#			individual tests from their respective files.

############
# Requires #
############

if RUBY_VERSION[0..2] == '1.9'
	begin
		require 'simplecov'
		SimpleCov.start do
			add_filter 'tc_*'
			add_filter 'generated*'
		end
		
	rescue LoadError
		puts 'SimpleCov not installed.  Continuing without it.'
	end
end

# Rubygems
require 'rubygems'
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

begin
	class Tester
		extend FFI::Library
		
		ffi_lib("LLVM-#{RLTK::LLVM_TARGET_VERSION}")
	end
	
	# The test suite for the LLVM bindings
	require 'cg/ts_cg'
rescue
end
