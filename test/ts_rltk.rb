# Author:      Chris Wailes <chris.wailes@gmail.com>
# Project:     Ruby Language Toolkit
# Date:        2011/04/06
# Description: This file contains the test suit for RLTK.  It requires the
#              individual tests from their respective files.

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

# Ruby Language Toolkit
require 'rltk/version'

# Test cases
require 'tc_token'
require 'tc_ast'
require 'tc_cfg'
require 'tc_lexer'
require 'tc_parser'
