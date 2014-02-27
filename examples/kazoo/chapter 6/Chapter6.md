# Kazoo - Chapter 6: Adding Control Flow

Welcome to Chapter 5 of the  tutorial.  Chapters 1-4 described the implementation of the simple Kazoo language and included support for generating LLVM IR, followed by optimizations and a JIT compiler.  Unfortunately, as presented, Kazoo is mostly useless: it has no control flow other than call and return.  This means that you can't have conditional branches in the code, significantly limiting its power.  In this episode of "Build That Compiler", we'll extend Kazoo to have an if/then/else expression plus a simple 'for' loop.

The old version of Chapter 6 can be found [here](file.Chapter6-old.html).

## If/Then/Else

Extending Kazoo to support if/then/else is quite straightforward.  It basically requires adding lexer support for this "new" concept to the lexer, parser, AST, and LLVM code emitter.  This example is nice, because it shows how easy it is to "grow" a language over time, incrementally extending it as new ideas are discovered.

Before we get going on "how" we add this extension, lets talk about "what" we want.  The basic idea is that we want to be able to write this sort of thing:

```
def fib(x)
  if x < 2 then
    1
  else
    fib(x-1)+fib(x-2);
```

In Kazoo, every construct is an expression: there are no statements.  As such, the if/then/else expression needs to return a value like any other.  Since we're using a mostly functional form, we'll have it evaluate its conditional, then return the 'then' or 'else' value based on how the condition was resolved.  This is very similar to the C "?:" expression.

The semantics of the if/then/else expression is that it evaluates the condition to a boolean equality value: 0.0 is considered to be false and everything else is considered to be true.  If the condition is true, the first subexpression is evaluated and returned, if the condition is false, the second subexpression is evaluated and returned.  Since Kazoo allows side-effects, this behavior is important to nail down.

Now that we know what we "want", lets break this down into its constituent pieces.

### Lexer Extensions for If/Then/Else

The lexer extensions are straightforward, and all we need to do is add three new rules:

```Ruby
rule(/if/)   { :IF     }
rule(/then/) { :THEN   }
rule(/else/) { :ELSE   }
```

### AST Extensions for If/Then/Else

To represent the new expression we add a new AST class for it, which has as children representing the conditional, then block, and else block:

```Ruby
class If < Expression
  child :cond, Expression
  child :then, Expression
  child :else, Expression
end
```

### Parser Extensions for If/Then/Else

Now that we have the relevant tokens coming from the lexer and we have the AST node to build, our parsing logic is relatively straightforward.  We simply need to add a new clause to the expression production:

```Ruby
clause('IF e THEN e ELSE e') { |_, e0, _, e1, _, e2| If.new(e0, e1, e2) }
```

### LLVM IR for If/Then/Else

Now that we have it parsing and building the AST, the final piece is adding LLVM code generation support.  This is the most interesting part of the if/then/else example, because this is where it starts to introduce new concepts.  To motivate the code we want to produce, lets take a look at a simple example.  Consider:

```
extern foo();
extern bar();
def baz(x) if x then foo() else bar();
```

If you disable optimizations, the code you'll (soon) get from Kazoo looks like this:

```
declare double @foo()

declare double @bar()

define double @baz(double %x) {
entry:
  %ifcond = fcmp one double %x, 0.000000e+00
  br i1 %ifcond, label %then, label %else

then:    ; preds = %entry
  %calltmp = call double @foo()
  br label %merge

else:    ; preds = %entry
  %calltmp1 = call double @bar()
  br label %merge

merge:    ; preds = %else, %then
  %iftmp = phi double [ %calltmp, %then ], [ %calltmp1, %else ]
  ret double %iftmp
}
```

This code is fairly simple: the entry block evaluates the conditional expression ("x" in our case here) and compares the result to 0.0 with the "fcmp one" instruction ('one' is "Ordered and Not Equal").  Based on the result of this expression, the code jumps to either the "then" or "else" blocks, which contain the expressions for the true/false cases.

Once the then/else blocks are finished executing, they both branch back to the 'merge' block to execute the code that happens after the if/then/else.  In this case the only thing left to do is to return to the caller of the function.  The question then becomes: how does the code know which expression to return?

The answer to this question involves an important SSA operation: the [Phi operation](http://en.wikipedia.org/wiki/Static_single_assignment_form).  If you're not familiar with SSA, the [wikipedia article](http://en.wikipedia.org/wiki/Static_single_assignment_form) is a good introduction and there are various other introductions to it available on your favorite search engine.  The short version is that "execution" of the Phi operation requires "remembering" which block control came from.  The Phi operation takes on the value corresponding to the input control block.  In this case, if control comes in from the "then" block, it gets the value of "calltmp".  If control comes from the "else" block, it gets the value of "calltmp1".

At this point, you are probably starting to think "Oh no! This means my simple and elegant front-end will have to start generating SSA form in order to use LLVM!".  Fortunately, this is not the case, and we strongly advise not implementing an SSA construction algorithm in your front-end unless there is an amazingly good reason to do so.  In practice, there are two sorts of values that float around in code written for your average imperative programming language that might need Phi nodes:

1. Code that involves user variables: `x = 1; x = x + 1;`
2. Values that are implicit in the structure of your AST, such as the Phi node in this case.

In Chapter 8 of this tutorial ("Mutable Variables"), we'll talk about #1 in depth.  For now, just believe me that you don't need SSA construction to handle this case.  For #2, you have the choice of using the techniques that we will describe for #1, or you can insert Phi nodes directly, if convenient. In this case, it is really really easy to generate the Phi node, so we choose to do it directly.

Okay, enough of the motivation and overview, lets generate code!

### Code Generation for If/Then/Else

In order to generate code for this we will add an additional visitor case that starts as follows:

```Ruby
on If do |node|
  cond_val = fcmp :one, (visit node.cond), ZERO, 'ifcond'
```

This code is straightforward and similar to what we saw before.  We visit the node's conditional expression and then compare that value to zero to get a truth value as a 1-bit (bool) value.  The variable `ZERO` is defined inside the Kazoo module, and represents a constant with value 0.0.

```Ruby
start_bb = current_block
fun      = start_bb.parent

then_bb               = fun.blocks.append('then')
then_val, new_then_bb = visit node.then, at: then_bb, rcb: true
```

We start off by saving a pointer to the first block (which might not be the entry block), which we'll need to build a conditional branch later.  We do this by asking the contractor for the current BasicBlock.  The second line gets the current Function object that is being built.  It gets this by asking the start_bb for its "parent" (the function it is currently embedded into).  Once we have the function we creat a new block.  It is automatically appended into the function's list of blocks.

Next, we recrusively translate the "then" expression from the AST.  Using the `:at` argument we tell the contractor to start inserting into the "then" block.  Stricctly speaking, this call moves the insertion point to be at the end of the specified block.  However, since the "then" block is empty, it starts by inserting at the beginning of the block.

This call to `visit` also uses the `:rcb` option (which stands for 'return current block'), which is very important.  The basic issue is that when we create the Phi node in the merge block later, we need to set up the block/value pairs that indicate how the Phi node will work.  Importantly, the Phi node expects to have an entry for each predecessor of the block in the CFG.  Why then, are we getting the current block when we just set it to `then_bb` using the `:at` argument in the same call?  The problem is that the "then" expresison may have changed the block that the contractor is emitting into if, for example, it contains a nested "if/then/else" expression.  Because calling `visit` recursively could arbitrarily change the notion of the *current block*, we are required to get an up-to-date value for code that will set up the Phi node.

Code generation for the 'else' block is basically identical what we did for the 'then' block:

```Ruby
else_bb               = fun.blocks.append('else')
else_val, new_else_bb = visit node.else, at: else_bb, rcb: true
```

Next, we must build our merge block:

```Ruby
merge_bb = fun.blocks.append('merge', self)
phi_inst = build(merge_bb) { phi RLTK::CG::DoubleType, {new_then_bb => then_val, new_else_bb => else_val}, 'iftmp' }
```

The first line her should be familiar: it adds the "merge" block to the Function object.  The second line uses the {RLTK::CG::Builder#build build} method to position the builder and then execute the provided block.  In this case the block generates a Phi node with type {RLTK::CG::DoubleType}.  The mapping between predecessor blocks and values is provided by the hash, and the result of the Phi node will be stored in a variable named "iftmp".

Once we have created the then_bb, else_bb, and merge_bb blocks we can emit the conditional branch that will chose between the first two.  Note that creating new blocks does not implicitly affect the builder, so it is still inserting into the else_bb block or wherever translating the *else* expression positioned the contractor.  This is why we needed to save the start_bb.

```Ruby
build(start_bb) { cond cond_val, then_bb, else_bb }
```

To finish off the *then* and *else* blocks, we create an unconditional branch to the merge block.

```Ruby
build(new_then_bb) { br merge_bb }
build(new_else_bb) { br merge_bb }
```

One interesting (and very important) aspect of the LLVM IR is that it [requires all basic blocks to be "terminated"](http://llvm.org/docs/LangRef.html#functionstructure) with a [control flow instruction](http://llvm.org/docs/LangRef.html#terminators) such as return or branch.  This means that all control flow, including fall throughs, must be made explicit in the LLVM IR. If you violate this rule, the verifier will emit an error.  As such, we must return the phi node as the value computed by the if/then/else expression.  In our example above, this returned value will feed into the code for the top-level function, which will create the return instruction.  Before doing that, however, we reposition the contractor at the end of the merge_bb to allow later instructions to be inserted in the correct position.

```Ruby
returning(phi_inst) { target merge_bb }
```

Overall, we now have the ability to execute conditional code in Kazoo.  With this extension, Kazoo is a fairly complete language that can calculate a wide variety of numeric functions.  Next up we'll add another useful expression that is familiar from non-functional languages...

## 'for' Loop Expressions

Now that we know how to add basic control flow constructs to the language, we have the tools to add more powerful things. Lets add something more aggressive, a 'for' expression:

```
extern putchard(char);
def printstar(n)
  for i = 0, i < n, 1.0 in
    putchard(42);  # ascii 42 = '*'

# print 100 '*' characters
printstar(100);
```

This expression defines a new variable ("i" in this case) which iterates from a starting value, while the condition (`i < n` in this case) is true, incrementing by a step value ("1.0" in this case).  While the loop is true, it executes its body expression.  Because we don't have anything better to return, we'll just define the loop as always returning 0.0.  In the future when we have mutable variables, it will get more useful.

As before, lets talk about the changes that we need to Kazoo to support this.

### Lexer Extensions for the 'for' Loop

The lexer extensions are the same sort of thing as for if/then/else:

```Ruby
rule(/for/) { :FOR    }
rule(/in/)  { :IN     }
```

### AST Extensions for the 'for' Loop

The AST variant is just as simple.  It basically boils down to capturing the variable name and the constituent expressions in the node.

```Ruby
class For < Expression
  value :var, String

  child :init, Expression
  child :cond, Expression
  child :step, Expression
  child :body, Expression
end
```

### Parser Extensions for the 'for' Loop

The parser code is also fairly standard:

```Ruby
clause('FOR IDENT ASSIGN e COMMA e COMMA e IN e') do |_, i, _, e0, _, e1, _, e2, _, e3|
  For.new(i, e0, e1, e2, e3)
end
```

### LLVM IR for the 'for' Loop

Now we get to the good part: the LLVM IR we want to generate for this thing.  With the simple example above, we get this LLVM IR (note that this dump is generated with optimizations disabled for clarity):

```
declare double @putchard(double)

define double @printstar(double %n) {
entry:
  br label %loop_cond

loop_cond:                                        ; preds = %loop, %entry
  %i = phi double [ 1.000000e+00, %entry ], [ %nextvar, %loop ]
  %cmptmp = fcmp ult double %i, %n
  br i1 %cmptmp, label %loop, label %afterloop

loop:                                             ; preds = %loop_cond
  %calltmp = call double @putchard(double 4.200000e+01)
  %nextvar = fadd double %i, 1.000000e+00
  br label %loop_cond

afterloop:                                        ; preds = %loop_cond
  ret double 0.000000e+00
}
```

This loop contains all the same constructs we saw before: a phi node, several expressions, and some basic blocks.  Let's see how this fits together.

### Code Generation for the 'for' Loop

The first part of our new visitor code sets up a couple of basic blocks for us to insert into.  `ph_bb` is the current block, and will be used to set up the initial value and branch into the `loop_cond_bb`.  The `loop_cond_bb` will hold the code responsible for determining if the loop should execute an iteration.

```Ruby
on For do |node|
  ph_bb        = current_block
  fun          = ph_bb.parent
  loop_cond_bb = fun.blocks.append('loop_cond')
```

Now that this is done we can generate the initial value for the loop variable and then add the unconditional branch to the `loop_cond_bb` basic block.

```Ruby
init_val = visit node.init
br loop_cond_bb
```

The `loop_cond` basic block will need a Phi node to receive incoming values from the preheader basic block and the loop basic block, so we build the node and then add it to our symbol table.  The old value is kept so that it can be restored later.  This allows loop variables to shadow existing ones.

```Ruby
var = build(loop_cond_bb) { phi RLTK::CG::DoubleType, {ph_bb => init_val}, node.var }

old_var = @st[node.var]
@st[node.var] = var
```

The next step is to generate the code for testing the termination condition:

```Ruby
end_cond = fcmp :one, (visit node.cond), ZERO, 'loopcond'
```

We'll eventually need to insert a branch into this basic block, but that can't happen until we have references to several blocks that haven't been built yet.  So, instead, we'll move on to the loop basic block where we'll add the code for the loop's body.

```Ruby
loop_bb0 = fun.blocks.append('loop')
		
_, loop_bb1 = visit node.body, at: loop_bb0, rcb: true
```

Notice the last line where we get a new reference to the insert block using the `:rcb` option.  This is to handle cases where the body of the loop caused new basic_blocks to be added to the function.  This reference will be needed to add an incoming branch to the `var` Phi node, which is what we do right after we calculate the value to be added to the node:

```Ruby
step_val = visit node.step
next_var = fadd var, step_val, 'nextvar'

var.incoming.add({loop_bb1 => next_var})

br loop_cond_bb
```

After we've added the new value to the Phi node we build the unconditional branch back to the `loop_cond` basic block.

The last basic block that we need to create we won't actually generate code for.  It is simply used as the exit block for the loop where subsequent expressions will be translated.  This last basic block will also allow us to add our last remaining branch instruction and then reset the builder for future translations:

```Ruby
after_bb = fun.blocks.append('afterloop')

build(loop_cond_bb) { cond end_cond, loop_bb0, after_bb }

target after_bb
```

The only thing remaining now is to do some cleanup.  We first need to restore the `old_var` variable to the symbol table.  The absolute last thing that needs to happen is to return zero.  This is because all expressions must return some value and zero makes as much sense as any other value.

```Ruby
@st[node.var] = old_var

ZERO
```

With this, we conclude the "Adding Control Flow to Kazoo" chapter of the tutorial.  In this chapter we added two control flow constructs, and used them to motivate a couple of aspects of the LLVM IR that are important for front-end implementors to know.  In the [next chapter](file.Chapter7.html), we will add a couple of additional operators to Kazoo and then use them to do some actual computation.  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 6`" directory.
