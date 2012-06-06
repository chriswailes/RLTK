# Kazoo - Chapter 8: Mutable Variables

Welcome to Chapter 8 of the tutorial.  In chapters 1 through 6 we've built a very respectable, albeit simple, [functional programming language](http://en.wikipedia.org/wiki/Functional_programming).  In our journey we learned some parsing techniques, how to build and represent an AST, how to build LLVM IR, and how to optimize the resultant code as well as JIT compile it.

While Kazoo is interesting as a functional language, the fact that it is functional makes it "too easy" to generate LLVM IR for it.  In particular, a functional language makes it very easy to build LLVM IR directly in SSA form.  Since LLVM requires that the input code be in SSA form, this is a very nice property and it is often unclear to newcomers how to generate code for an imperative language with mutable variables.

The short (and happy) summary of this chapter is that there is no need for your front-end to build SSA form: LLVM provides highly tuned and well tested support for this, though the way it works is a bit unexpected for some.

To understand why mutable variables cause complexities in SSA construction, consider this extremely simple C example:

	int g, h;
	int test(bool condition) {
		int x;
		if (condition)
			x = g;
		else
			x = h;
		return x;
	}

In this case, we have the variable "x", whose value depends on the path executed in the program.  Because there are two different possible values for x before the return instruction a PHI node is inserted to merge the two values.  The LLVM IR that we want for this example looks like this:

	@g = weak global i32 0   ; type of @g is i32*
	@h = weak global i32 0   ; type of @h is i32*

	define i32 @test(i1 %condition) {
	entry:
		br i1 %condition, label %cond_true, label %cond_false

	cond_true:
		%x.0 = load i32* @g
		br label %cond_next

	cond_false:
		%x.1 = load i32* @h
		br label %cond_next

	cond_next:
		%x.2 = phi i32 [ %x.1, %cond_false ], [ %x.0, %cond_true ]
		ret i32 %x.2
	}

In this example, the loads from the g and h global variables are explicit in the LLVM IR, and they live in the then/else branches of the if statement (cond\_true/cond\_false).  In order to merge the incoming values, the x.2 phi node in the cond\_next block selects the right value to use based on where control flow is coming from: if control flow comes from the con\_false block, x.2 gets the value of x.1.  Alternatively, if control flow comes from cond\_true, it gets the value of x.0.  For more information, see one of the many [online references](http://en.wikipedia.org/wiki/Static_single_assignment_form).

The question for this chapter is "Who places the phi nodes when lowering assignments to mutable variables?".  The issue here is that LLVM requires that its IR be in SSA form: there is no "non-ssa" mode for it.  However, SSA construction requires non-trivial algorithms and data structures, so it is inconvenient and wasteful for every front-end to have to reproduce this logic.

The 'trick' here is that while LLVM does require all register values to be in SSA form, it does not require (or permit) memory objects to be in SSA form.  In the example above, note that the loads from g and h are direct accesses to g and h: they are not renamed or versioned.  This differs from some other compiler systems, which do try to version memory objects.  In LLVM, instead of encoding dataflow analysis of memory into the LLVM IR, it is handled with [Analysis Passes](http://llvm.org/docs/WritingAnLLVMPass.html) which are computed on demand.

With this in mind, the high-level idea is that we want to make a stack variable (which lives in memory, because it is on the stack) for each mutable object in a function.  To take advantage of this trick we need to talk about how LLVM represents stack variables.

In LLVM, all memory accesses are explicit with load/store instructions, and it is carefully designed not to have (or need) an "address-of" operator.  Notice how the type of the `@g`/`@h` global variables is actually "i32*" even though the variable is defined as "i32".  What this means is that `@g` defines space for an i32 in the global data area, but its name actually refers to the address for that space.  Stack variables work the same way, except that instead of being declared with global variable definitions they are declared with the LLVM alloca instruction:

	define i32 @example() {
	entry:
		%x = alloca i32           ; type of %x is i32*.
		...
		%tmp = load i32* %x       ; load the stack value %x from the stack.
		%tmp2 = add i32 %tmp, 1   ; increment it
		store i32 %tmp2, i32* %x  ; store it back

This code shows an example of how you can declare and manipulate a stack variable in the LLVM IR.  Stack memory allocated with the alloca instruction is fully general: you can pass the address of the stack slot to functions, you can store it in other variables, etc.  In our example above, we could rewrite the example to use the alloca technique to avoid using a Phi node:

	@g = weak global i32 0   ; type of @g is i32*
	@h = weak global i32 0   ; type of @h is i32*

	define i32 @test(i1 %condition) {
	entry:
		%X = alloca i32           ; type of %x is i32*.
		br i1 %condition, label %cond_true, label %cond_false

	cond_true:
		%x.0 = load i32* @g
		store i32 %x.0, i32* %x   ; Update x
		br label %cond_next

	cond_false:
		%x.1 = load i32* @h
		store i32 %x.1, i32* %x   ; Update x
		br label %cond_next

	cond_next:
		%x.2 = load i32* %x       ; Read x
		ret i32 %x.2
	}

With this, we have discovered a way to handle arbitrary mutable variables without the need to create Phi nodes at all:


* Each mutable variable becomes a stack allocation.
* Each read of the variable becomes a load from the stack.
* Each update of the variable becomes a store to the stack.
* Taking the address of a variable just uses the stack address directly.

While this solution has solved our immediate problem, it introduced another one: we have now apparently introduced a lot of stack traffic for very simple and common operations, a major performance problem.  Fortunately for us, the LLVM optimizer has a highly-tuned optimization pass named "mem2reg" that handles this case, promoting allocas like this into SSA registers, inserting Phi nodes as appropriate. If you run this example through the pass, for example, you'll get:

	$ llvm-as < example.ll | opt -mem2reg | llvm-dis
	@g = weak global i32 0
	@h = weak global i32 0

	define i32 @test(i1 %condition) {
	entry:
		br i1 %condition, label %cond_true, label %cond_false

	cond_true:
		%x.0 = load i32* @g
		br label %cond_next

	cond_false:
		%x.1 = load i32* @h
		br label %cond_next

	cond_next:
		%x.01 = phi i32 [ %x.1, %cond_false ], [ %x.0, %cond_true ]
		ret i32 %x.01
	}

The mem2reg pass implements the standard "iterated dominance frontier" algorithm for constructing SSA form and has a number of optimizations that speed up (very common) degenerate cases.  The mem2reg optimization pass is the answer to dealing with mutable variables, and we highly recommend that you depend on it.  Note that mem2reg only works on variables in certain circumstances:

* mem2reg is alloca-driven: it looks for allocas and if it can handle them, it promotes them.  It does not apply to global variables or heap allocations.
* mem2reg only looks for alloca instructions in the entry block of the function.  Being in the entry block guarantees that the alloca is only executed once, which makes analysis simpler.
* mem2reg only promotes allocas whose uses are direct loads and stores.  If the address of the stack object is passed to a function, or if any funny pointer arithmetic is involved, the alloca will not be promoted.
* mem2reg only works on allocas of [first class](http://llvm.org/docs/LangRef.html#t_classifications) values (such as pointers, scalars and vectors), and only if the array size of the allocation is 1 (or missing in the .ll file).  mem2reg is not capable of promoting structs or arrays to registers. Note that the "scalarrepl" pass is more powerful and can promote structs, unions, and arrays in many cases.

All of these properties are easy to satisfy for most imperative languages and we'll illustrate it below with Kazoo.  The final question you may be asking is: should I bother with this nonsense for my front-end?  Wouldn't it be better if I just did SSA construction directly, avoiding use of the mem2reg optimization pass?  In short, we strongly recommend that you use this technique for building SSA form unless there is an extremely good reason not to. Using this technique is:

* Proven and well tested: llvm-gcc and clang both use this technique for local mutable variables.  As such, the most common clients of LLVM are using this to handle a bulk of their variables. You can be sure that bugs are found fast and fixed early.
* Extremely Fast: mem2reg has a number of special cases that make it fast in common cases as well as fully general.  For example, it has fast-paths for variables that are only used in a single block, variables that only have one assignment point, good heuristics to avoid insertion of unneeded phi nodes, etc.
* Needed for debug info generation: Debug information in LLVM relies on having the address of the variable exposed so that debug info can be attached to it.  This technique dovetails very naturally with this style of debug info.

If nothing else, this makes it much easier to get your front-end up and running, and is very simple to implement.  Lets extend Kazoo with mutable variables now!

## Mutable Variables in Kazoo

Now that we know the sort of problem we want to tackle, lets see what this looks like in the context of our little Kazoo language.  We're going to add two features:

* The ability to mutate variables with the '=' operator.
* The ability to define new variables.

While the first item is really what this is about, we only have variables for incoming arguments as well as for induction variables, and redefining those only goes so far.  Also, the ability to define new variables is a useful thing regardless of whether you will be mutating them.  Here's a motivating example that shows how we could use these:

	# Recursive fib; we could do this before.
	def fib(x)
		if (x < 3) then
			1
		else
			fib(x-1) + fib(x-2);

	# Iterative fib.
	def fibi(x)
		a = 1 : b = 1 : c = 0 :
		(for i = 2, i < x, 1 in
			c = a + b :
			a = b :
			b = c) :
		b;

	# Call it.
	fibi(10);

In order to mutate variables, we have to change our existing variables to use the "alloca trick".  Once we have that, we'll add our new operator, then extend Kazoo to support new variable definitions.

The symbol table in Kazoo is managed at code generation time by the `@st` hash.  This hash currently keeps track of the LLVM "Value*" that holds the double value for the named variable.  In order to support mutation, we need to change this slightly, so that if `@st` holds the memory location of the variable in question.  Note that this change is a refactoring: it changes the structure of the code, but does not (by itself) change the behavior of the compiler.  All of these changes are isolated in the Kazoo code generator.

At this point in Kazoo's development variables are only supported in two cases: incoming arguments to functions and the induction variable of 'for' loops.  For consistency, we'll allow mutation of these variables in addition to other user-defined variables.  This means that these will both need memory locations.

The first functionality change we want to make is to variable references.  In our new scheme, variables live on the stack, so code generating a reference to them actually needs to produce a load from the stack slot:

	when Variable
		if @st.key?(node.name)
			@builder.load(@st[node.name], node.name)
		
		else
			raise Exception, "Unitialized variable '#{node.name}'."
		end

As you can see, this is pretty straightforward.  Now we need to update the things that define the variables to set up the alloca.  We'll start with `translate_expression`'s For branch:

	ph_bb			= @builder.current_block
	fun				= ph_bb.parent
	loop_cond_bb	= fun.blocks.append('loop_cond')
	
	alloca		= @builder.alloca(RLTK::CG::DoubleType, node.var)
	init_val	= translate_expression(node.init)
	@builder.store(init_val, alloca)
	
	old_var = @st[node.var]
	@st[node.var] = alloca
	
	@builder.br(loop_cond_bb)
	
	# Translate the conditional code.
	@builder.position_at_end(loop_cond_bb)
	end_cond = translate_expression(node.cond)
	end_cond = @builder.fcmp(:one, end_cond, ZERO, 'loopcond')
	
	loop_bb0 = fun.blocks.append('loop')
	@builder.position_at_end(loop_bb0)
	
	translate_expression(node.body)
	
	loop_bb1 = @builder.current_block
	
	step_val	= translate_expression(node.step)
	var			= @builder.load(alloca, node.var)
	next_var	= @builder.fadd(var, step_val, 'nextvar')
	@builder.store(next_var, alloca)
	
	@builder.br(loop_cond_bb)
	
	# Add the conditional branch to the loop_cond_bb.
	after_bb = fun.blocks.append('afterloop')
	
	loop_cond_bb.build { cond(end_cond, loop_bb0, after_bb) }
	
	@builder.position_at_end(after_bb)
	
	@st[node.var] = old_var
	
	ZERO

This code is largely identical to the code from the previous chapters.  Notice, however, the new store instruction for the initial value, the removal of the Phi instruction, and the load and store instructions around the `next_var`.

To support mutable argument variables we need to also make allocas for them.  This is accomplished by making changes to the `translate_prototype` and `translate_function` methods.

The change to `translate_prototype` removes the code that stores the argument's value in the symbol table.  Here is the old code and the new code for comparison:

	# Old Code
	node.arg_names.each_with_index do |name, i|
		(@st[name] = fun.params[i]).name = name
	end

	# New Code
	node.arg_names.each_with_index do |name, i|
		fun.params[i].name = name
	end

Instead of adding entries to the symbol table in the `translate_prototype` method we will instead add them in the `translate_function` method:

	# Create a new basic block to insert into, allocate space for
	# the arguments, store their values, translate the expression,
	# and set its value as the return value.
	fun.blocks.append('entry', nil, @builder, self, @st) do |jit, st|
		fun.params.each do |param|
			st[param.name] = alloca(RLTK::CG::DoubleType, param.name)
			store(param, st[param.name])
		end
		
		ret jit.translate_expression(node.body)
	end

This new loop not only allocates space for them and adds the address to the symbol table, but it also stores the argument's values in these locations.

The code generated by these translation functions will be far from optimal.  It will include many accesses to memory that could be avoided if we hadn't included mutable variables in Kazoo.  To improve this situation we will add the *promote memory to registers* pass to our pass manager.

	# Add passes to the Function Pass Manager.
	@engine.fpm.add(:InstCombine, :Reassociate, :GVN, :CFGSimplify, :PromoteMemToReg)

It is interesting to see what the code looks like before and after the mem2reg optimization runs.  For example, this is the before/after code for our recursive fib function. Before the optimization:

	define double @fib(double %x) {
	entry:
		%x1 = alloca double
		store double %x, double* %x1
		%x2 = load double* %x1
		%cmptmp = fcmp ult double %x2, 3.000000e+00
		%booltmp = uitofp i1 %cmptmp to double
		%ifcond = fcmp one double %booltmp, 0.000000e+00
		br i1 %ifcond, label %then, label %else

	then:                                             ; preds = %entry
		br label %merge

	else:                                             ; preds = %entry
		%x3 = load double* %x1
		%subtmp = fsub double %x3, 1.000000e+00
		%calltmp = call double @fib(double %subtmp)
		%x4 = load double* %x1
		%subtmp5 = fsub double %x4, 2.000000e+00
		%calltmp6 = call double @fib(double %subtmp5)
		%addtmp = fadd double %calltmp, %calltmp6
		br label %merge

	merge:                                            ; preds = %else, %then
		%iftmp = phi double [ 1.000000e+00, %then ], [ %addtmp, %else ]
		ret double %iftmp
	}

Here there is only one variable (x, the input argument) but you can still see the extremely simple-minded code generation strategy we are using.  In the entry block, an alloca is created, and the initial input value is stored into it.  Each reference to the variable does a reload from the stack.  Also, note that we didn't modify the if/then/else expression, so it still inserts a Phi node. While we could make an alloca for it, it is actually easier to create a PHI node for it, so we still just make the Phi.

Here is the code after the mem2reg pass runs:

	define double @fib(double %x) {
	entry:
		%cmptmp = fcmp ult double %x, 3.000000e+00
		%booltmp = uitofp i1 %cmptmp to double
		%ifcond = fcmp one double %booltmp, 0.000000e+00
		br i1 %ifcond, label %then, label %else

	then:                                             ; preds = %entry
		br label %merge

	else:                                             ; preds = %entry
		%subtmp = fsub double %x, 1.000000e+00
		%calltmp = call double @fib(double %subtmp)
		%subtmp5 = fsub double %x, 2.000000e+00
		%calltmp6 = call double @fib(double %subtmp5)
		%addtmp = fadd double %calltmp, %calltmp6
		br label %merge

	merge:                                            ; preds = %else, %then
		%iftmp = phi double [ 1.000000e+00, %then ], [ %addtmp, %else ]
		ret double %iftmp
	}

This is a trivial case for mem2reg, since there are no redefinitions of the variable.  The point of showing this is to calm your tension about inserting such blatant inefficiencies.

After the rest of the optimizers run, we get:

	define double @fib(double %x) {
	entry:
		%cmptmp = fcmp ult double %x, 3.000000e+00
		br i1 %cmptmp, label %merge, label %else

	else:                                             ; preds = %entry
		%subtmp = fadd double %x, -1.000000e+00
		%calltmp = call double @fib(double %subtmp)
		%subtmp5 = fadd double %x, -2.000000e+00
		%calltmp6 = call double @fib(double %subtmp5)
		%addtmp = fadd double %calltmp, %calltmp6
		br label %merge

	merge:                                            ; preds = %entry, %else
		%iftmp = phi double [ %addtmp, %else ], [ 1.000000e+00, %entry ]
		ret double %iftmp
	}

## The Assignment Operator

With our current framework adding a new assignment operator is fairly simple.  The first step is to add a new AST node class for the operator:

	class Assign < Expression
		value :name, String
	
		child :right, Expression
	end

Next we'll add a new clause to the parser (inside the `e` production):

	clause('IDENT ASSIGN e')	{ |e0, _, e1| Assign.new(e0, e1) }

The last thing to do is to add is a new clause to the `translate_expression` method:

	when Assign
		right = translate_expression(node.right)
		
		alloca =
		if @st.has_key?(node.name)
			@st[node.name]
		else
			@st[node.name] = @builder.alloca(RLTK::CG::DoubleType, node.name)
		end
		
		@builder.store(right, alloca)

If a memory location with the name of the left-hand side isn't present in the symbol table a new alloca instruction is generated and the memory location is inserted into the symbol table.  This allows you to define a variable simply by assigning to it.

Now that we have an assignment operator, we can mutate any variable in Kazoo. For example, we can now run code like this:

	extern putsd(d);

	def test(x)
		putd(x) : x = 4 : putd(x);

	test(123);

When run, this example prints "123" and then "4", showing that we did actually mutate the value!

With this, we completed what we set out to do.  Our nice iterative fib example from the intro compiles and runs just fine.  The mem2reg pass optimizes all of our stack variables into SSA registers, inserting Phi nodes where needed, and our front-end remains simple: no "iterated dominance frontier" computation anywhere in sight.

This concludes the Kazoo tutorial.  We now have a Turing complete language and a JIT compiler for it.  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 8`" directory.
