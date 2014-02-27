# Kazoo - Chapter 1: The Lexer

When it comes to implementing a language, the first thing needed is the ability to process a text file and recognize what it says.  The traditional way to do this is to use a *lexer* (aka *scanner*) to break the input up into *tokens*.  Each token returned by the lexer includes a token code and potentially some metadata (e.g. the numeric value of a number).

It is pretty simple to create a lexer using RLKT:

```Ruby
class Lexer < RLTK::Lexer; end
```

Next we will define a set of rules inside the class definition that will tell the lexer how to convert strings into tokens.  The first rule we will add simply discards any whitespace encountered.

```Ruby
rule(/\s/)
```

This is simply a call to the {RLTK::Lexer.rule} class function.  The first argument is the regular expression that describes substrings of the input that match this rule.  Most of the rules we will define have actions associated with them that tell the lexer how to emit {RLTK::Token tokens}, but because we simply want to discard any whitespace we can can leave the action blank.  The default action associated with a rule returns `nil` and any action that returns `nil` emits no token.

Rules for keywords and operators can be added very simply:

```Ruby
# Keywords
rule(/def/)    { :DEF    }
rule(/extern/) { :EXTERN }

# Operators and delimiters.
rule(/\(/) { :LPAREN }
rule(/\)/) { :RPAREN }
rule(/;/)  { :SEMI   }
rule(/,/)  { :COMMA  }
rule(/=/)  { :ASSIGN }
rule(/\+/) { :PLUS   }
rule(/-/)  { :SUB    }
rule(/\*/) { :MUL    }
rule(/\//) { :DIV    }
rule(/</)  { :LT     }
```

Each rule has an associated action that returns a single symbol when evaluated.  These symbols are used to construct RLTK::Token objects that have their `type` attribute set to the returned symbol.  The token objects also contain formation about their source file, line number, line offset, and length.

In Kazoo we will use a token type identifier (or :IDENT) to indicate a variable or function name.  We would like these identifiers to start with a letter, but after that they may contain letters or numbers. A rule to capture these identifiers can be defined as such:

```Ruby
# Identifier rule.
rule(/[A-Za-z][A-Za-z0-9]*/) { |t| [:IDENT, t] }
```

Here we specify an action that takes a single parameter, `t`, which will contain the text matched by the rule’s regular expression.  The rule’s action then returns an array where the first element is the token’s type, and the second element is the token’s value.

Next, we’re going to add rules for matching numbers.  These rules are very similar to the identifier rule, in that they take their matched text and use it to give the generated token a value, but in this case we convert the text from a string to a float using Ruby’s built-in `to_f` method.

```Ruby
# Numeric rules.
rule(/\d+/)      { |t| [:NUMBER, t.to_f] }
rule(/\.\d+/)    { |t| [:NUMBER, t.to_f] }
rule(/\d+\.\d+/) { |t| [:NUMBER, t.to_f] }
```

Not that many people are going to need to leaving comments in Kazoo code, but they are a good way to show off some of the more advanced functionality in the {RLTK::Lexer} class so lets think about the behavior we want out of the lexer when we encounter a comment (which start with a # in Kazoo).  As we are only going to support line comments the lexer should discard all input after a # until it encounters a newline.  To achieve this behavior we will use the lexers state stack.

```Ruby
# Comment rules.
rule(/#/)            { push_state :comment }
rule(/\n/, :comment) { pop_state }
rule(/./, :comment)
```

When attempting to match a substring of the input RLTK lexers only use the rules that are defined for their current state.  The first rule says that when the lexer encounters a # it should enter the `:comment` state.  The second rule says that if we encounter a newline we should pop the current state off of the state stack, but *only* if we are already in the `:comment` state.  Lastly, we add a rule that will discard any single character input. Since this rule is specified after the newline rule we will never discard a newline.

And that finishes our lexer for now! The full code for this chapter can be found in the "`examples/kazoo/chapter 1`" directory.  Continue on to the [next chapter](file.Chapter2.html) to see how we use RLTK to define AST nodes for Kazoo.
