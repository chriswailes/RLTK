# Kazoo - Chapter 5: JIT Compilation

In the previous chapters we described the implementation of the lexer, parser, and AST for our simple language, Kazoo, and added support for generating LLVM IR for it.  This chapter describes two new techniques: adding optimizer support to your language, and adding JIT compiler support. These additions will demonstrate how to get nice, efficient code for the Kazoo language.

## LLVM Optimization Passes

LLVM provides many optimization passes which do many different sorts of things and have different tradeoffs.  Unlike other systems, LLVM doesn't hold to the mistaken notion that one set of optimizations is right for all languages and for all situations.  LLVM allows a compiler implementor to make complete decisions about what optimizations to use, in which order, and in what situation.

As a concrete example, LLVM supports both "whole module" passes, which look across as large of body of code as they can (often a whole file, but if run at link time, this can be a substantial portion of the whole program).  It also supports and includes "per-function" passes which just operate on a single function at a time, without looking at other functions.  For more information on passes and how they are run, see the [How to Write a Pass](http://llvm.org/docs/WritingAnLLVMPass.html) document and the [List of LLVM Passes](http://llvm.org/docs/WritingAnLLVMPass.html).

For Kazoo, we are currently generating functions on the fly, one at a time, as the user types them in.  We aren't shooting for the ultimate optimization experience in this setting, but we also want to catch the easy and quick stuff where possible.  As such, we will choose to run a few per-function optimizations as the user types the function in.  If we wanted to make a "static Kazoo compiler", we would use exactly the code we have now, except that we would defer running the optimizer until the entire file has been parsed.

In order to get per-function optimizations going, we will use a {RLTK::CG::FunctionPassManager FunctionPassManager} to hold and organize the LLVM optimizations that we want to run.  We can now add a set of optimizations to run.  We will be adding the manager to our JIT class's initialization method like so:

	def initialize
		# IR building objects.
		@module	= RLTK::CG::Module.new('Kazoo JIT')
		@builder	= RLTK::CG::Builder.new
		@st		= Hash.new
		
		# Execution Engine
		@engine = RLTK::CG::JITCompiler.new(@module)
		
		# Add passes to the Function Pass Manager.
		@engine.fpm.add(:InstCombine, :Reassociate, :GVN, :CFGSimplify)
	end

Each {RLTK::CG::ExecutionEngine} provides both a PassManager and FunctionPassManager object when they are requested, and handles their initialization.  Once our FunctionPassManager is set up, we use the {RLTK::CG::PassManager#add add} method to add a bunch of LLVM passes.  The `@engine` variable is related to the JIT, which we will get to in the next section.

In this case, we choose to add four optimization passes.  The passes we chose here are a pretty standard set of "cleanup" optimizations that are useful for a wide variety of code.  I won't delve into what they do but, believe me, they are a good starting place :).

Once the {RLTK::CG::FunctionPassManager} is set up we need to make use of it.  We do this by adding an `optimize` method to our JIT class that we can call on functions returned by the `add` method:

	def optimize(fun)
		@engine.fpm.run(fun)

		fun
	end

As you can see, this is pretty straightforward. The FunctionPassManager optimizes and updates the LLVM Function in place, improving (hopefully) its body.  With this in place, we can try a simple test:

	Kazoo > def test(x) (1+2+x)*(x+(1+2));
	Before optimization:

	define double @test(double %x) {
	entry:
		%addtmp = fadd double 3.000000e+00, %x
		%addtmp1 = fadd double %x, 3.000000e+00
		%multmp = fmul double %addtmp, %addtmp1
		ret double %multmp
	}

	After optimization:

	define double @test(double %x) {
	entry:
		%addtmp = fadd double %x, 3.000000e+00
		%multmp = fmul double %addtmp, %addtmp
		ret double %multmp
	}

As expected, we now get our nicely optimized code, saving a floating point add instruction from every execution of this function.

LLVM provides a wide variety of optimizations that can be used in certain circumstances.  Some [documentation about the various passes](http://llvm.org/docs/Passes.html) is available, but it isn't very complete.  Another good source of ideas can come from looking at the passes that llvm-gcc or llvm-ld run to get started.  The "opt" tool allows you to experiment with passes from the command line, so you can see if they do anything.

Now that we have reasonable code coming out of our front-end, lets talk about executing it!

## Adding a JIT Compiler

Code that is available in LLVM IR can have a wide variety of tools applied to it.  For example, you can run optimizations on it (as we did above), you can dump it out in textual or binary forms, you can compile the code to an assembly file (.s) for some target, or you can JIT compile it.  The nice thing about the LLVM IR representation is that it is the "common currency" between many different parts of the compiler.

In this section, we'll add JIT compiler support to our interpreter.  The basic idea that we want for Kazoo is to have the user enter function bodies as they do now, but immediately evaluate the top-level expressions they type in.  For example, if they type in `1 + 2;`, we should evaluate and print out 3. If they define a function, they should be able to call it from the command line.

We've already taken steps toward adding JIT compilation support.  If you look at the section above that added the function pass manager you'll see the following line:

	@engine = RLTK::CG::JITCompiler.new(@module)

This creates an abstract "Execution Engine" which can be either a JIT compiler or the LLVM interpreter.  LLVM will automatically pick a JIT compiler for you if one is available for your platform, otherwise it will fall back to the interpreter.

Once the {RLTK::CG::JITCompiler} is created the JIT is ready to be used.  There are a variety of APIs that are useful, but the simplest one is the {RLTK::CG::ExecutionEngine#run\_function run\_function} function.  This method JIT compiles the specified LLVM Function and returns a function pointer to the generated machine code.  In our case, this means that we can change the driver code to look like this:

	ast = Kazoo::Parser::parse(Kazoo::Lexer::lex(line))
	ir  = jit.add(ast)

	puts "Before optimization:"
	ir.dump

	puts "After optimization:"
	jit.optimize(ir).dump

	if ast.is_a?(Kazoo::Expression)
		puts "=> #{jit.execute(ir).to_f(RLTK::CG::DoubleType)}"
	end

Recall that we compile top-level expressions into a self-contained LLVM function that takes no arguments and returns the computed double.  Because the LLVM JIT compiler matches the native platform ABI you can just cast the result pointer to a function pointer of that type and call it directly.  This means there is no difference between JIT compiled code and native machine code that is statically linked into your application.

With just these two changes, lets see how Kazoo works now (the output below is slightly elided)!

	Kazoo > 4 + 5;

	define double @1() {
	entry:
		ret double 9.000000e+00
	}

	=> 9.0

Well this looks like it is basically working.  The dump of the function shows the "no argument function that always returns double" that we synthesize for each top level expression that is typed in.  This demonstrates very basic functionality, but can we do more?

	Kazoo > def testfunc(x,y) x + y*2;

	define double @testfunc(double %x, double %y) {
	entry:
		%multmp = fmul double %y, 2.000000e+00
		%addtmp = fadd double %multmp, %x
		ret double %addtmp
	}

	Kazoo > testfunc(4, 10);

	define double @2() {
	entry:
		%calltmp = call double @testfunc(double 4.000000e+00, double 1.000000e+01)
		ret double %calltmp
	}

	=> 24.0

This illustrates that we can now call user code, but there is something a bit subtle going on here.  Note that we only invoke the JIT on the anonymous functions that calls `testfunc`, but we never invoked it on `testfunc` itself.  What actually happened here is that the JIT scanned for all non-JIT'd functions transitively called from the anonymous function and compiled all of them before returning from `run_function`.

The JIT provides a number of other more advanced interfaces for things like freeing allocated machine code, rejit'ing functions to update them, etc. However, even with this simple code, we get some surprisingly powerful capabilities - check this out:

	Kazoo > extern sin(x);

	declare double @sin(double)

	Kazoo > extern cos(x);

	declare double @cos(double)

	Kazoo > sin(1.0);
	Before optimization:

	define double @0() {
	entry:
		%calltmp = call double @sin(double 1.000000e+00)
		ret double %calltmp
	}

	After optimization:

	define double @0() {
	entry:
		ret double 0x3FEAED548F090CEE
	}

	=> 0.841470984807897

	Kazoo > def foo(x) sin(x)*sin(x) + cos(x)*cos(x);

	define double @foo(double %x) {
	entry:
		%calltmp = call double @sin(double %x)
		%calltmp1 = call double @sin(double %x)
		%multmp = fmul double %calltmp, %calltmp1
		%calltmp2 = call double @cos(double %x)
		%calltmp3 = call double @cos(double %x)
		%multmp4 = fmul double %calltmp2, %calltmp3
		%addtmp = fadd double %multmp, %multmp4
		ret double %addtmp
	}

	Kazoo > foo(4.0);

	define double @1() {
	entry:
		%calltmp = call double @foo(double 4.000000e+00)
		ret double %calltmp
	}

	=> 1.0

Whoa, how does the JIT know about `sin` and `cos`?  The answer is surprisingly simple: in this example, the JIT started execution of a function and got to a function call.  It realized that the function was not yet JIT compiled and invoked the standard set of routines to resolve the function.  In this case, there is no body defined for the function, so the JIT ended up calling `dlsym("sin")` on the Kazoo process itself.  Since `sin` is defined within the JIT's address space, it simply patches up calls in the module to call the libm version of sin directly.

The LLVM JIT provides a number of interfaces for controlling how unknown functions get resolved.  It allows you to establish explicit mappings between IR objects and addresses (useful for LLVM global variables that you want to map to static tables, for example), allows you to dynamically decide on the fly based on the function name, and even allows you to have the JIT compile functions lazily the first time they're called.

One interesting application of this is that we can now extend the language by writing arbitrary C code to implement operations. For example, if we compile the following C code into a shared library and load it into the process we can call it from our JIT:

	/* putchard - putchar that takes a double and returns 0. */
	double putchard(double x) {
		putchar((char) x);
		return 0;
	}

To load this library (`libkazoo.so`) and inform LLVM about it we'll add the following line to our driver program:

	RLTK::CG::Support.load_library('./libkazoo.so')

Now we can produce simple output to the console by using things like: "`extern putchard(x); putchard(120);`", which prints a lowercase 'x' on the console (120 is the ASCII code for 'x').  Similar code could be used to implement file I/O, console input, and many other capabilities in Kazoo.

This completes the JIT and optimizer chapter of the Kazoo tutorial. At this point, we can compile a non-Turing-complete programming language, optimize and JIT compile it in a user-driven way.  In the [next chapter](file.Chapter6.html) we'll look into extending the language with control flow constructs, tackling some interesting LLVM IR issues along the way.  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 5`" directory.
