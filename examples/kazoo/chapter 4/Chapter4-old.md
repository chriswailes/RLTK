# Kazoo - Chapter 4: AST Translation

In this chapter we will be translating the AST that our parser builds into LLVM intermediate representation (IR).  This will teach you a little bit about how LLVM does things, as well as demonstrate how easy it is to use.

## Code Generation Setup

In order to generate LLVM IR, we need to perform some simple setup to get started.  We need to tell LLVM that we will be working on an x86 platform by making a call to the {RLTK::CG::LLVM.init} method.  This will go at the top of our 'kjit.rb' file which will hold most of our code for this chapter.  Here is a quick outline of the file:

	RLTK::CG::LLVM.init(:X86)

	class JIT
		attr_reader :module

		def initialize
		end

		def add(ast)
		end

		def translate_expression(node)
		end

		def translate_function(node)
		end

		def translate_prototype(node)
		end
	end

The translate methods will emit IR for that AST node along with all the things it depends on, and they all return an LLVM Value object.  The {RLTK::CG::Value} class represents a "Static Single Assignment (SSA) register" or "SSA value" in LLVM.  The most distinct aspect of SSA values is that their value is computed as the related instruction executes, and it does not get a new value until (and if) the instruction re-executes.  In other words, there is no way to "change" an SSA value.  For more information you can read the Wikipedia article on [Static Single Assignment](http://en.wikipedia.org/wiki/Static_single_assignment_form) - the concepts are really quite natural once you grok them.

The last bit of setup is to tell the JIT to create a new {RLTK::CG::Module}, {RLTK::CG::Builder}, and symbol table when it is initialized.

	def initialize
		# IR building objects.
		@module	= LLVM::Module.create('Kazoo JIT')
		@builder	= LLVM::Builder.create
		@st		= Hash.new
	end

The {RLTK::CG::Module} class is the LLVM construct that contains all of the functions and global variables in a chunk of code. In many ways, it is the top-level structure that the LLVM IR uses to contain code.  The {RLTK::CG::Builder} object is a helper object that makes it easy to generate LLVM instructions.  Instances of the Builder class keep track of the current place to insert instructions and has methods to create new instructions.  The symbol table (`@st`) keeps track of which values are defined in the current scope and what their LLVM representation is.  In this form of Kazoo, the only things that can be referenced are function parameters.  As such, function parameters will be in this map when generating code for their function body.

With these basics in place, we can start talking about how to generate code for each expression.

## Expression Translation

Generating LLVM code for expression nodes is very straightforward.  First we'll do numeric literals:

	when Number
		RLTK::CG::Double.new(node.value)

In the LLVM IR, floating point constants are represented with the {RLTK::CG::Float} and {RLTK::CG::Double} classes.  This code simply creates and returns a {RLTK::CG::Double} constant.

References to variables are also quite simple using LLVM.  In the simple version of Kazoo, we assume that the variable has already been emitted somewhere and its value is available.  In practice, the only values that can be in the symbol table are function arguments.  This code simply checks to see that the specified name is in the table (if not, an unknown variable is being referenced) and returns the value for it.  In future chapters we'll add support for loop induction variables in the symbol table, and for local variables.

	when Variable
		if @st.key?(node.name)
			@st[node.name]
		else
			raise "Unitialized variable '#{node.name}'."
		end

Binary operators start to get more interesting.  The basic idea here is that we recursively emit code for the left-hand side of the expression, then the right-hand side, then we compute the result of the binary expression.  In this code, we check the class of the node, and generate LLVM instructions appropriately.

	when Binary
		left  = translate_expression(node.left)
		right = translate_expression(node.right)

		case node
		when Add
			@builder.fadd(left, right, 'addtmp')

		when Sub
			@builder.fsub(left, right, 'subtmp')

		when Mul
			@builder.fmul(left, right, 'multmp')

		when Div
			@builder.fdiv(left, right, 'divtmp')

		when LT
			cond = @builder.fcmp(:ult, left, right, 'cmptmp')
			@builder.ui2fp(cond, LLVM::Double, 'booltmp')
		end

In the example above, the LLVM builder class is starting to show its value.  Builder knows where to insert the newly created instruction, all you have to do is specify what instruction to create (e.g. with `@builder.add`), which operands to use (lhs and rhs here) and optionally provide a name for the generated instruction.

One nice thing about LLVM is that the name is just a hint.  For instance, if the code above emits multiple "addtmp" variables, LLVM will automatically provide each one with an increasing, unique numeric suffix.  Local value names for instructions are purely optional, but it makes it much easier to read the IR dumps.

LLVM instructions are constrained by strict rules: for example, the *left* and *right* operators of an add instruction must have the same type, and the result type of the add must match the operand types.  Because all values in Kazoo are doubles, this makes for very simple code for add, sub and mul.

On the other hand, LLVM specifies that the fcmp instruction always returns an `i1` value (a one bit integer).  The problem with this is that Kazoo wants the value to be a 0.0 or 1.0 value.  In order to get these semantics, we combine the fcmp instruction with a uitofp instruction. This instruction converts its input integer into a floating point value by treating the input as an unsigned value.  In contrast, if we used the sitofp instruction, the Kazoo '<' operator would return 0.0 and -1.0, depending on the input value.

Code generation for function calls is simple as well:

	when Call
		callee = @module.functions.named(node.name)

		if not callee
			raise 'Unknown function referenced.'
		end

		if callee.params.size != node.args.length
			raise "Function #{node.name} expected #{callee.params.size} argument(s) but was called with #{node.args.length}."
		end

		args = node.args.map { |arg| translate_expression(arg) }
		@builder.call(callee, *args.push('calltmp'))

The code above initially does a function name lookup in the LLVM Module's symbol table.  Recall that the LLVM Module is the container that holds all of the functions we are JIT'ing. By giving each function the same name as what the user specifies, we can use the LLVM symbol table to resolve function names for us.

Once we have the function to call, we recursively translate each argument that is to be passed in, and create an LLVM call instruction.  Note that LLVM uses the native C calling conventions by default, allowing these calls to also call into standard library functions like `sin` and `cos`, with no additional effort.

## Function Code Generation

Code generation for prototypes and functions must handle a number of details, which make their code less aesthetically pleasing than expression code generation, but allows us to illustrate some important points.  First, lets talk about code generation for prototypes: they are used both for function bodies and external function declarations. The code starts with:

	if fun = @module.functions[node.name]
		if fun.blocks.size != 0
			raise "Redefinition of function #{node.name}."
			
		elsif fun.params.size != node.arg_names.length
			raise "Redefinition of function #{node.name} with different number of arguments."
		end
	else
		fun = @module.functions.add(node.name, RLTK::CG::DoubleType, Array.new(node.arg_names.length, RLTK::CG::DoubleType))
	end

The first thing this code does is check to see if a function has already been declared with the specified name.  If such a function has been seen before it then checks to make sure it has the same argument list and an zero-length body.  If this function name has not been seen before a new function is created.  The `Array.new(...)` call produces an array that tells LLVM the type of each of the functions arguments.

This code allows function redefinition in two cases: first, we want to allow 'extern'ing a function more than once, as long as the prototypes for the externs match (since all arguments have the same type, we just have to check that the number of arguments match).  Second, we want to allow 'extern'ing a function and then defining a body for it. This is useful when defining mutually recursive functions.

The last bit of code for prototypes loops over all of the arguments in the function, setting the name of the LLVM Argument objects to match, and registering the arguments in the symbol table for future use by the `translate_expression` method.  Once this is set up, it returns the {RLTK::CG::Function Function} object to the caller.  Note that we don't check for conflicting argument names here (e.g. "extern foo(a, b, a)"). Doing so would be very straight-forward with the mechanics we have already used above.

	# Name each of the function paramaters.
	returning(fun) do
		node.arg_names.each_with_index do |name, i|
			(@st[name] = fun.params[i]).name = name
		end
	end

The last translation function we need to write is for Function nodes.  We start by translating the prototype and verifying that it is OK.  We then clear out the symbol table to make sure that there isn't anything in it from the last function we compiled.  Translation of the prototype ensures that there is an LLVM Function object that is ready to go for us.

	# Reset the symbol table.
	@st.clear

	# Translate the function's prototype.
	fun = translate_prototype(node.proto)

Next, we create a new basic block at the end of the function's list of basic blocks, and then tell the builder to insert new instructions into this new block.  This is done here by passing a block to the `append` function, which will then forward this block along to be executed inside a Builder.  Notice that we pass `self` to the `append` function.  This is because the given block is executed in a context where we wouldn't have a reference to the JIT object.  By passing it in to `append` it will then be yielded to our block.  Basic blocks in LLVM are an important part of functions that define the Control Flow Graph.  Since we don't have any control flow, our functions will only contain one block at this point.

Once the insertion point is set up, we call the `translate_expression` method for the root expression of the function.  If no error happens, this emits code to compute the expression into the entry block and returns the value that was computed.  Assuming no error, we then create an LLVM ret instruction, which completes the function.  Once the function is built, we call `verify` method on the function, which is provided by LLVM.  This method does a variety of consistency checks on the generated code, to determine if our compiler is doing everything right.  Using this is important: it can catch a lot of bugs.  Once the function is finished and validated, we return it.

	# Create a new basic block to insert into, translate the
	# expression, and set its value as the return value.
	fun.blocks.append('entry', nil, @builder, self) do |jit|
		ret jit.translate_expression(node.body)
	end
	
	# Verify the function and return it.
	returning(fun) { fun.verify }

## It's All Starting To Come Together!

For now, code generation to LLVM doesn't really get us much, except that we can look at the pretty IR calls. The driver file for this chapter changes things up a little bit and will use the JIT to generate our IR and print it out.  This gives a nice way to look at the LLVM IR for simple functions.  For example:

	Kazoo > 4 + 5;

	define double @0() {
	entry:
		ret double 9.000000e+00
	}

Note how the parser turns the top-level expression into anonymous functions for us.  This will be handy when we add JIT support in the next chapter.  Also note that the builder did the addition for us.  This is called constant folding, and is something that the basic builder class does for us.

This next example shows some simple arithmetic.  Notice the striking similarity to the LLVM builder calls that we use to create the instructions.

	Kazoo > def foo(a,b) a*a + 2*a*b + b*b;

	define double @foo(double %a, double %b) {
	entry:
		%multmp = fmul double %a, %a
		%multmp1 = fmul double %a, %b
		%multmp2 = fmul double 2.000000e+00, %multmp1
		%addtmp = fadd double %multmp, %multmp2
		%multmp3 = fmul double %b, %b
		%addtmp4 = fadd double %addtmp, %multmp3
		ret double %addtmp4
	}

Now we can do some simple function calls.  Note that this function will take a long time to execute if you call it. In the future we'll add conditional control flow to actually make recursion useful :).

	Kazoo > def bar(a) foo(a, 4.0) + bar(31337);

	define double @bar(double %a) {
	entry:
		%calltmp = call double @foo(double %a, double 4.000000e+00)
		%calltmp1 = call double @bar(double 3.133700e+04)
		%addtmp = fadd double %calltmp, %calltmp1
		ret double %addtmp
	}

Here is how you declare an external function and then call it:

	Kazoo > extern cos(x);

	declare double @cos(double)

	Kazoo > cos(1.234);

	define double @1() {
	entry:
		%calltmp = call double @cos(double 1.234000e+00)
		ret double %calltmp
	}

When you quit the current demo, it dumps out the IR for the entire module generated.  Here you can see the big picture with all the functions referencing each other.

This wraps up the third chapter of the Kazoo tutorial.  In the [next chapter](file.Chapter5.html) we'll describe how to add JIT compilation and optimization support to this so we can actually start running code!  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 4`" directory.
