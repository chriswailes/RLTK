# Kazoo - Chapter 3: The Parser

The lexer takes in plain text and outputs a list of tokens, which we need to then convert into an abstract syntax tree.  To do this we will write a [parser](http://en.wikipedia.org/wiki/Parsing) using the RLTK::Parser parser generating class.  This starts out much the same as when we defined our lexer:

```Ruby
class Parser < RLTK::Parser; end
```

Inside this class definition we will add *productions* (instead of *rules*) that will build an AST from the input token list.  These productions define a [context free grammar](http://en.wikipedia.org/wiki/Context-free_grammar) (CFG) that is the formal definition of the structure of the language.  In the RLTK universe symbols in **ALL_CAPS** are terminal symbols, and symbols in **all_lowercase** are non-terminal symbols.

The first production defined in the parser is considered the starting production, and can be thought of as the eventual goal of the parser when it is looking at input.  Our first production will simply say that a valid input is a statement followed by a semicolon, and that this should evaluate to whatever the statement evaluates to:

```Ruby
production(:input, 'statement SEMI') { |s, _| s }
```

Here it is important to note two things:


* A production's action must have the same number of arguments as there are symbols on the right-hand side of the production (unless the `array_args` method is invoked).
* The arguments passed to a production's action are the values returned from other production's actions.  In this case the argument `s` will hold a value obtained from a production's action with a left-hand side of 'statement'.

In Kazoo a statement can be an expression, an external function declaration, a function prototype, or a function.  Translating this to Ruby we end up with:

```Ruby
production(:statement) do
  clause('e')  { |e| e }
  clause('ex') { |e| e }
  clause('p')  { |p| p }
  clause('f')  { |f| f }
end
```

So, what does an expression (*e*) look like?  Well, pretty similar to the structure of our AST node definitions actually.

```Ruby
production(:e) do
  clause('LPAREN e RPAREN') { |_, e, _| e }

  clause('NUMBER') { |n| Number.new(n)   }
  clause('IDENT')  { |i| Variable.new(i) }

  clause('e PLUS e') { |e0, _, e1| Add.new(e0, e1) }
  clause('e SUB e')  { |e0, _, e1| Sub.new(e0, e1) }
  clause('e MUL e')  { |e0, _, e1| Mul.new(e0, e1) }
  clause('e DIV e')  { |e0, _, e1| Div.new(e0, e1) }
  clause('e LT e')   { |e0, _, e1| LT.new(e0, e1)  }

  clause('IDENT LPAREN args RPAREN') { |i, _, args, _| Call.new(i, args) }
end
```

You may notice that we are passing arguments to our AST node's initialize method even though we didn't define one for our classes.  This is all taken care of for us by the {RLTK::ASTNode} class, and we can simply pass in the node's values followed by its children (in order of definition).

The last clause shown defines what a function call looks like, but we haven't said what a function call's arguments look like.  We'd like them to be a comma separated list of expressions, and so extend our parser as such:

```Ruby
production(:args) do
  clause('')         { || []       }
  clause('arg_list') { |args| args }
end

production(:arg_list) do
  clause('e')                { |e| [e]                 }
  clause('e COMMA arg_list') { |e, _, args| [e] + args }
end
```

The first clause is necessary as it allows us to have a function call with zero arguments.  The `:arg_list` production will take care of cases where we have one or more arguments.

External function declarations, function prototypes, and function definitions are all closely related, and rely on similar concepts as the productions discussed above.

```Ruby
production(:ex, 'EXTERN p_body') { |_, p| p                  }
production(:p, 'DEF p_body')     { |_, p| p                  }
production(:f, 'p e')            { |p, e| Function.new(p, e) }

production(:p_body, 'IDENT LPAREN arg_defs RPAREN') do |name, _, arg_names, _|
  Prototype.new(name, arg_names)
end

production(:arg_defs) do
  clause('')             { || []       }
  clause('arg_def_list') { |args| args }
end

production(:arg_def_list) do
  clause('IDENT')                    { |i| [i]                 }
  clause('IDENT COMMA arg_def_list') { |i, _, defs| [i] + defs }
end
```

After all of the productions for our parser are defined we must call `finalize` on it.  To decrease the amount of time it takes to load the parser we give it the `:use` option, which tells the parser to store a version of it's parser table in the 'kparser.tbl' file.    The next time the kparser.rb file is required it will check to see if the 'kparser.tbl' file exists and if it is up to date; if it meets these requirements it will load the saved data instead of rebuilding the entire parser.

```Ruby
production(:arg_def_list) do
  clause('IDENT')                    { |i| [i]                 }
  clause('IDENT COMMA arg_def_list') { |i, _, defs| [i] + defs }
end

finalize({:use => 'kparser.tbl'})
```

This will cause the parser to construct internal data structures that will be used during the parsing of input.

Now that we have a working lexer, parser, and AST definition we can use a simple driver program to test our code.  Notice how it only takes one line to lex and parse and input string, yielding a complete AST.

```Ruby
loop do
  line = ask('Kazoo > ')

  break if line == 'quit' or line == 'exit'

  begin
    ast = Kazoo::Parser::parse(Kazoo::Lexer::lex(line))

    case ast
    when Expression then puts 'Parsed an expression.'
    when Function   then puts 'Parsed a function definition.'
    when Prototype  then puts 'Parsed a prototype or extern definition.'
    end

  rescue RLTK::NotInLanguage
    puts 'Line was not in language.'
  end
end
```

The driver doesn't do much yet, but in the [next chapter](file.Chapter4.html) we will add support for translating our AST into LLVM intermediate representation.  The full code listing for this chapter can be found in the "`examples/kazoo/chapter 3`" directory.
