# Kazoo - Chapter 2: The AST Nodes

Now that we have defined the tokens that make up a Kazoo program we can define a set of abstract syntax tree (AST) nodes that we will use to build an internal representation of the program for our compiler.

First, we will create a node class called Expression which will be subclasses by various other node types.  This empty definition doesn’t look like much now, but it will be useful for later definitions.

```Ruby
class Expression < RLTK::ASTNode; end
```

Number and Variable nodes are used to encapsulate literal floating point values and the names assigned to various memory locations.  Both are types of expressions, and as such subclass the Expression class.

```Ruby
class Number < Expression
  value :value, Float
end

class Variable < Expression
  value :name, String
end
```

The call to the value class function tell the Number class that it will have a single value named :value, and that it will be of type Float.  Accessor methods will then be define that do the proper type checking during runtime.  We’d also like to be able to represent binary expressions such as addition and multiplication, so we add the following definitions:

```Ruby
class Binary < Expression
  child :left, Expression
  child :right, Expression
end

class Add < Binary; end
class Sub < Binary; end
class Mul < Binary; end
class Div < Binary; end
class LT  < Binary; end
```

In the definition of the Binary class we use the child method instead of the value method to define the members left and right, both with type Expression.  The differences between values and children is that the type of a child must inherit from the {RLTK::ASTNode} class.  This allows you to easily traverse your AST using functions like parent, root, and each (which iterates over a node’s children).

We define an AST node for function calls slightly differently.

```Ruby
class Call < Expression
  value :name, String

  child :args, [Expression]
end
```

By passing the child method a type specification inside of an array, we are telling the Call class that the member args should be an array containing only Expression objects.

Lastly, we add definitions for AST nodes representing function prototypes and definitions.

```Ruby
class Prototype < RLTK::ASTNode
  value :name, String
  value :arg_names, [String]
end

class Function < RLTK::ASTNode
  child :proto, Prototype
  child :body, Expression
end
```

In the [next chapter](file.Chapter3.html) we will write a parser that takes input from our lexer and uses the AST node definitions to build an AST from our input. The full code for this chapter can be found in the "`examples/kazoo/chapter 2`" directory.
