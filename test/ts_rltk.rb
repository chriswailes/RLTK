# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/04/06
# Description:	This file contains test suit for RLTK.  It requires the
#			individual tests from their respective files.

############
# Requires #
############

if RUBY_VERSION.match(/1\.9/)
	begin
		require 'simplecov'
		SimpleCov.start do
			add_filter 'tc_*'
		end
		
	rescue LoadError
		puts 'SimpleCov not installed.  Continuing without it.'
	end
end

# Ruby Language Toolkit
require 'tc_token'
require 'tc_ast'
require 'tc_cfg'
require 'tc_lexer'
require 'tc_parser'
