Bugs
====

These are issues that are preventing the library from working correctly.

Ruby Only
---------

* Find a way to deal with the 'B? B' example (B? should be nil and B should hold the value).
* Don't overwrite explain file when loading from cache.

Binding Wrappers
----------------

* None

LLVM C Bindings
---------------

* None

Features
========

These are items that would provide additional features to RLTK users.

Whole Project
-------------

* Convert to Ruby 2.0 syntax.
  * Move to lazy enumerators
  * Keyword arguments
  * Nested methods
  * New lambda syntax
  * New hash syntax
  * Inject methods
* Update the documentation to use the @overloaded tag.

Ruby Only
---------

* Whent he parse stack is split clone the environment
* Double check parse table production method against LALR/LR table production
  * Check lookahead pruning method to see if generating LALR(1) or LR(1) parser
  * If we are generating LR(1) parser, correct documentation
  * If we are generating LALR(1) parser, switch to LR(1) parser generation
* Re-read the Menhir manual to look for features missing from RLTK.
* Add a function to print out in ASTs dot language.
* Add a default action for parser clauses that returns the value of a production with a single RHS symbol or an array of values of a production with multiple RHS symbols (get rid of the need to do `clause('foo') { |o| o }`).
* Add support for parentheses in CFGs.
* Add the ability to print out CFG in a textual form.
* Add a way of setting a default lexer class for a parser.
* Allow a parser to accept strings as input and then use either a provided lexer or the default lexer to lex the string.
* Allow the first argument of the associativity methods to be an integer to be used as the value for those tokens.  An error should be raised if associativity values are given in a non-increasing order.
* Investigate a better way of storing name and type information for values and children of ASTNodes, as well as better ways to define the accessors.
* Better reporting of shift/reduce and reduce/reduce conflicts in the parser.

Binding Wrappers
----------------

* Review and add to support for object finalization / memory cleanup
* Find home for unwrapped C binding functions
* Figure out what an AssemblyAnnotationWriter is and what it is used for.
* Add additional support for MCJIT.  This may require adding new bindings to LLVM 3.5. (http://llvm.org/docs/MCJITDesignAndImplementation.html)
  * Lazy compilation (http://blog.llvm.org/2013/07/using-mcjit-with-kaleidoscope-tutorial.html, http://blog.llvm.org/2013/07/kaleidoscope-performance-with-mcjit.html)
  * Object caching (http://blog.llvm.org/2013/08/object-caching-with-kaleidoscope.html)
* Support disassembly of objects
* Re-do the construction of binding objects from pointers

LLVM C Bindings
---------------

* Add C and Ruby bindings for additional atomic instructions

Crazy Ideas
===========

These are items that will require a significant amount of work to investigate their practicality and utility, let alone implement them.

Ruby Only
---------

* Add an optimization function for grammars.  One example optimization would be replacing nonterminals that only produce a single item.  Kind of like constant and reference propagation.  Another optimization would be looking for different productions that have different left-hand side symbols but the same right-hand side.
* Composable parsers
* Composable lexers
* Single token at a time lexer.

Binding Wrappers
----------------

* None

LLVM C Bindings
---------------

* None
