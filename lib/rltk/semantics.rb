# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/07/27
# Description:	This file adds some autoload features for the formal semantics
#			features of RLTK.

#######################
# Classes and Modules #
#######################

module RLTK # :nodoc:
	
	# This module contains classes and methods for defining, manipulating, and
	# transforming formal semantics.
	module Semantics
		autoload :Actor,			'rltk/semantics/actor'
		autoload :Axiomatic,		'rltk/semantics/axiomatic'
		autoload :BigStep,			'rltk/semantics/big_step'
		autoload :Denotational,		'rltk/semantics/denotational'
		autoload :HoareLogic,		'rltk/semantics/hoare_logic'
		autoload :JoinCalculus,		'rltk/semantics/join_calculus'
		autoload :LambdaCalculus,	'rltk/semantics/lambda_calculus'
		autoload :Operational,		'rltk/semantics/operational'
		autoload :PiCalculus,		'rltk/semantics/pi_calculus'
		autoload :SmallStep,		'rltk/semantics/small_step'
	end
end
