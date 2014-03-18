# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for the RLTK::Util::AbstractClass
#			module.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/util/abstract_class'

#######################
# Classes and Modules #
#######################

class AbstractClassTester < Minitest::Test
	class Foo
		include AbstractClass
	end

	class Bar < Foo; end
	class Baz < Bar; end
	class Baf < Foo; end
	
	def test_new
		assert_raises(RuntimeError) { Foo.new }
	
		Bar.new
		Baz.new
		Baf.new
	end
end
