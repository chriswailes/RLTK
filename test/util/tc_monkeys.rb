# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/04
# Description:	This file contains unit tests for the monkey patches in the
#			rltk/util/monkeys.rb file.

############
# Requires #
############

# Gems
require 'minitest/autorun'

# Ruby Language Toolkit
require 'rltk/util/monkeys'

#######################
# Classes and Modules #
#######################

class MonkeyTester < Minitest::Test
	module Foo; end
	
	class Bar
		include Foo
	
		class Baf; end
	end
	
	class Baz < Bar; end
	
	def test_bool
		assert_equal(0, false.to_i)
		assert_equal(1, true.to_i)
	end
	
	def test_check_type
		assert(check_type([], Array))
		
		assert(check_type(1, Fixnum))
		assert(check_type(1, Fixnum, nil, true))
		assert(check_type(1, Integer))
		
		assert_raises(ArgumentError) { check_type(1, Integer, nil, true) }
		assert_raises(ArgumentError) { check_type(1, Array) }
	end
	
	def test_check_array_type
		assert(check_array_type([1, 2, 3], Fixnum))
		assert(check_array_type([1, 2, 3], Fixnum, nil, true))
		assert(check_array_type([1, 2, 3], Integer))
		
		assert_raises(ArgumentError) { check_array_type([1, 2, 3], Integer, nil, true) }
		assert_raises(ArgumentError) { check_array_type([1, :hello, 'world'], Fixnum) }
	end
	
	def test_class
		assert(Bar.includes_module?(Foo))
		
		assert_equal('MonkeyTester::Bar::Baf', Bar::Baf.name)
		assert_equal('Baf', Bar::Baf.short_name)
		
		assert(Baz.subclass_of?(Bar))
		assert(!Baz.subclass_of?(Fixnum))
		assert_raises(RuntimeError) { Baz.subclass_of?(1) }
	end
	
	def test_integer
		assert(!0.to_bool)
		assert( 1.to_bool)
		assert(10.to_bool)
	end
	
	def test_object
		assert_equal(:foo, returning(:foo) { 1 })
	end
end
