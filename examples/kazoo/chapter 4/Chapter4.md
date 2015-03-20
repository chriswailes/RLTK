# Kazoo - Chapter 4: AST Translation

In this chapter we will be translating the AST that our parser builds into LLVM intermediate representation (IR).  This will teach you a little bit about how LLVM does things, as well as demonstrate how easy it is to use.

Also of note is that in this chapter we begin to diverge more substantially from both previous versions of this tutorial and from LLVM's tutorial.  Older versions that use the {RLTK::CG::Builder} class directly will be linked at the beginning of each chapter.  As such, here is the link to the [old version of Chapter 4](file.Chapter4-old.html).

## Code Generation Setup

In order to generate LLVM IR, we need to perform some simple setup to get started.  We need to tell LLVM that we will be working on an x86 platform by making a call to the {RLTK::CG::LLVM.init} method.  This will go at the top of our 'kcontractor.rb' file which will hold most of our code for this chapter.  Here is a quick outline of the file:

```Ruby
RLTK::CG::LLVM.init(:X86)

class Contractor < RLTK::CG::Contractor
  attr_reader :module

  def initialize
  end

  def add(ast)
  end

  on Binary do |node|
  end

  on Call do |node|
  end

  on Variable do |node|
  end

  on Number do |node|
  end

  on Function do |node|
  end

  on Prototype do |node|
  end
end
```

The visitor `on` methods will emit IR for that AST node along with all the things it depends on, and they all return an LLVM Value object.  The {RLTK::CG::Value} class represents a "Static Single Assignment (SSA) register" or "SSA value" in LLVM.  The most distinct aspect of SSA values is that their value is computed as the related instruction executes, and it does not get a new value until (and if) the instruction re-executes.  In other words, there is no way to "change" an SSA value.  For more information you can read the Wikipedia article on [Static Single Assignment](http://en.wikipedia.org/wiki/Static_single_assignment_form) - the concepts are really quite natural once you grok them.

The last bit of setup is to tell the JIT to initialize the builder (it's superclass), and create a new {RLTK::CG::Module} and symbol table when it is initialized.

```Ruby
def initialize
  super

  # IR building objects.
  @module = RLTK::CG::Module.new('Kazoo JIT')
  @st     = Hash.new
end
```

The {RLTK::CG::Module} class is the LLVM construct that contains all of the functions and global variables in a chunk of code. In many ways, it is the top-level structure that the LLVM IR uses to contain code.  The {RLTK::CG::Contractor} class is a subclass of {RLTK::CG::Builder}, which is a helper object that is used to generate LLVM instructions.  The Contractor keeps track of the current place to insert instructions and has methods to create new instructions.  The symbol table (`@st`) keeps track of which values are defined in the current scope and what their LLVM representation is.  In this form of Kazoo the only things that can be referenced are function parameters.  As such, function parameters will be in this map when generating code for their function body.

With these basics in place, we can start talking about how to generate code for each expression.

## Expression Translation

Generating LLVM code for expression nodes is very straightforward.  First we'll do numeric literals:

```Ruby
on Number do |node|
  RLTK::CG::Double.new(node.value)
end
```

In the LLVM IR, floating point constants are represented with the {RLTK::CG::Float} and {RLTK::CG::Double} classes.  This code simply creates and returns a {RLTK::CG::Double} constant.

References to variables are also quite simple using LLVM.  In the simple version of Kazoo, we assume that the variable has already been emitted somewhere and its value is available.  In practice, the only values that can be in the symbol table are function arguments.  This code simply checks to see that the specified name is in the table (if not, an unknown variable is being referenced) and returns the value for it.  In future chapters we'll add support for loop induction variables in the symbol table, and for local variables.

```Ruby
on Variable do |node|
  if @st.key?(node.name)
    @st[node.name]
  else
    raise "Unitialized variable '#{node.name}'."
  end
end
```

Binary operators start to get more interesting.  The basic idea here is that we recursively emit code for the left-hand side of the expression, then the right-hand side, using the {RLTK::CG::Contractor#visit} method.  Then we compute the result of the binary expression.  In this code, we check the class of the node, and generate LLVM instructions appropriately.

```Ruby
on Binary do |node|
  left  = visit node.left
  right = visit node.right

  case node
  when Add then fadd(left, right, 'addtmp')
  when Sub then fsub(left, right, 'subtmp')
  when Mul then fmul(left, right, 'multmp')
  when Div then fdiv(left, right, 'divtmp')
  when LT  then ui2fp(fcmp(:ult, left, right, 'cmptmp'), RLTK::CG::DoubleType, 'booltmp')
  end
end
```

In the example above, the Contractor class is starting to show its value.  The Contracctor knows where to insert the newly created instruction, all you have to do is specify what instruction to create (e.g. with {RLTK::CG::Builder#fadd fadd}), which operands to use (left and right here) and optionally provide a name for the generated instruction.

One nice thing about LLVM is that the name is just a hint.  For instance, if the code above emits multiple "addtmp" variables, LLVM will automatically provide each one with an increasing, unique numeric suffix.  Local value names for instructions are purely optional, but it makes it much easier to read the IR dumps.

LLVM instructions are constrained by strict rules: for example, the *left* and *right* operators of an add instruction must have the same type, and the result type of the add must match the operand types.  Because all values in Kazoo are doubles, this makes for very simple code for add, sub and mul.

On the other hand, LLVM specifies that the fcmp instruction always returns an `i1` value (a one bit integer).  The problem with this is that Kazoo wants the value to be a 0.0 or 1.0 value.  In order to get these semantics, we combine the fcmp instruction with a uitofp instruction. This instruction converts its input integer into a floating point value by treating the input as an unsigned value.  In contrast, if we used the sitofp instruction, the Kazoo '<' operator would return 0.0 and -1.0, depending on the input value.

Code generation for function calls is simple as well:

```Ruby
on Call do |node|
  callee = @module.functions[node.name]

  if not callee
    raise 'Unknown function referenced.'
  end

  if callee.params.size != node.args.length
    raise "Function #{node.name} expected #{callee.params.size} argument(s) but was called with #{node.args.length}."
  end

  args = node.args.map { |arg| visit arg }
  call callee, *args.push('calltmp')
end
```

The code above initially does a function name lookup in the LLVM Module's symbol table.  Recall that the LLVM Module is the container that holds all of the functions we are JIT'ing. By giving each function the same name as what the user specifies, we can use the LLVM symbol table to resolve function names for us.

Once we have the function to call, we recursively translate each argument that is to be passed in, and create an LLVM call instruction.  Note that LLVM uses the native C calling conventions by default, allowing these calls to also call into standard library functions like `sin` and `cos`, with no additional effort.  The `args.push('calltmp')` simply adds a name for the variable that holds the value returned by the call instruction. 

## Function Code Generation

Code generation for prototypes and functions must handle a number of details, which make their code less aesthetically pleasing than expression code generation, but allows us to illustrate some important points.  First, lets talk about code generation for prototypes: they are used both for function bodies and external function declarations. The code starts with:

```Ruby
if fun = @module.functions[node.name]
  if fun.blocks.size != 0
    raise "Redefinition of function #{node.name}."

  elsif fun.params.size != node.arg_names.length
    raise "Redefinition of function #{node.name} with different number of arguments."
  
  else
    fun = @module.functions.add(node.name, RLTK::CG::DoubleType, Array.new(node.arg_names.length, RLTK::CG::DoubleType))
  end
end
```

The first thing this code does is check to see if a function has already been declared with the specified name.  If such a function has been seen before it then checks to make sure it has the same argument list and an zero-length body.  If this function name has not been seen before a new function is created.  The `Array.new(...)` call produces an array that tells LLVM the type of each of the functions arguments.

This code allows function redefinition in two cases: first, we want to allow 'extern'ing a function more than once, as long as the prototypes for the externs match (since all arguments have the same type, we just have to check that the number of arguments match).  Second, we want to allow 'extern'ing a function and then defining a body for it. This is useful when defining mutually recursive functions.

The last bit of code for prototypes loops over all of the arguments in the function, setting the name of the LLVM Argument objects to match, and registering the arguments in the symbol table for future use by the `translate_expression` method.  Once this is set up, it returns the {RLTK::CG::Function Function} object to the caller.  Note that we don't check for conflicting argument names here (e.g. "extern foo(a, b, a)"). Doing so would be very straight-forward with the mechanics we have already used above.

```Ruby
# Name each of the function paramaters.
returning(fun) do
  node.arg_names.each_with_index do |name, i|
    (@st[name] = fun.params[i]).name = name
  end
end
```

The last visitor function we need to write is for Function nodes.  We start by translating the prototype and verifying that it is OK.  We then clear out the symbol table to make sure that there isn't anything in it from the last function we compiled.  Translation of the prototype ensures that there is an LLVM Function object that is ready to go for us.

```Ruby
# Reset the symbol table.
@st.clear

# Translate the function's prototype.
fun = visit node.proto
```

The next step is to create a basic block for the functions body and then tel the contractor to insert new instructions into this new block.  The new block is created with via the function's basic block collection, accessible through {RLTK::CG::Function#blocks}.  Since we don't have any control flow our function will only contain a single basic block.  To position the contractor we will use the `:at` option of the {RLTK::CG::Contractor#visit} method.  This tells the contractor to target the end of the provided basic block before visiting the provided object.

If no error happens this will emit code to compute the expression into the entry block and return the value that was computed.  We then create an LLVM `ret` instruction, which completes the function.  Once the function is built we call the {RLTK::CG::Function#verify verify} method on the function, which is provided by LLVM.  This method does a variety of consistency checks on the generated code.  Using this is important as it can catch a lot of bugs.  Once the function is finished and verified we return it.

```Ruby
# Create a new basic block to insert into, translate the
# expression, and set its value as the return value.
ret (visit node.body, at: fun.blocks.append('entry'))

# Verify the function and return it.
returning(fun) { fun.verify }
```

## It's All Starting To Come Together!

For now, code generation to LLVM doesn't really get us much, except that we can look at the pretty IR calls. The driver file for this chapter changes things up a little bit and will use the JIT to generate our IR and print it out.  This gives a nice way to look at the LLVM IR for simple functions.  For example:
	
```
Kazoo > 4 + 5;

define double @0() {
entry:
	ret double 9.000000e+00
}
```

Note how the parser turns the top-level expression into anonymous functions for us.  This will be handy when we add JIT support in the next chapter.  Also note that the builder did the addition for us.  This is called constant folding, and is something that the basic builder class does for free.

This next example shows some simple arithmetic.  Notice the striking similarity to the LLVM builder calls that we use to create the instructions.

```
Kazoo > def foo(a,b) a*a + 2*a*b + b*b;

define double @foo(double %a, double %b) {
entry:
  %multmp = fmul double %a, %a
  %multmp1 = fmul double 2.000000e+00, %a
  %multmp2 = fmul double %multmp1, %b
  %addtmp = fadd double %multmp, %multmp2
  %multmp3 = fmul double %b, %b
  %addtmp4 = fadd double %addtmp, %multmp3
  ret double %addtmp4
}
```

Now we can do some simple function calls.  Note that this function will take a long time to execute if you call it. In the future we'll add conditional control flow to actually make recursion useful :).

```
Kazoo > def bar(a) foo(a, 4.0) + bar(31337);

define double @bar(double %a) {
entry:
  %calltmp = call double @foo(double %a, double 4.000000e+00)
  %calltmp1 = call double @bar(double 3.133700e+04)
  %addtmp = fadd double %calltmp, %calltmp1
  ret double %addtmp
}
```

Here is how you declare an external function and then call it:

```
Kazoo > extern cos(x);

declare double @cos(double)

Kazoo > cos(1.234);

define double @1() {
entry:
  %calltmp = call double @cos(double 1.234000e+00)
  ret double %calltmp
}
```

When you quit the current demo, it dumps out the IR for the entire module generated.  Here you can see the big picture with all the functions referencing each other.

This wraps up the third chapter of the Kazoo tutorial.  In the [next chapter](file.Chapter5.html) we'll describe how to add JIT compilation and optimization support to this so we can actually start running code!  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 4`" directory.
