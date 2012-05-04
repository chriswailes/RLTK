# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for the RLTK::Util::AbstractClass
#			module.

############
# Requires #
############

# Standard Library
require 'test/unit'

# Ruby Language Toolkit
require 'rltk/util/abstract_class'

#######################
# Classes and Modules #
#######################

class AbstractClassTester < Test::Unit::TestCase
	class Foo
		include AbstractClass
	end

	class Bar < Foo; end
	class Baz < Bar; end
	class Baf < Foo; end
	
	def test_new
		assert_raise(RuntimeError) { Foo.new }
	
		assert_nothing_raised { Bar.new }
		assert_nothing_raised { Baz.new }
		assert_nothing_raised { Baf.new }
	end
end
