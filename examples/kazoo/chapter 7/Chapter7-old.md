# Kazoo - Chapter 7: Playtime

So far we've been fairly constructive.  In the preceding chapters we've created a lexer, a parser, and AST nodes; we've learned how to generate LLVM IR from our AST and how to use the JIT class to compile and run our code; we've control flow to Kazoo.  Now it's time to slow down a bit and play with what we've created.

The first thing that we need to do is add some additional operators to the language.  These operators are | (or), & (and), < (greater than), : (sequencing), ! (not), and unary minus.  The changes necessary to add these operators are minimal and very similar to what we have done in previous chapters.  We'll only actually be using |, <, unary minus, and :, but the rest of the operators are useful demonstrations of some of the additional features of LLVM.  The operators all do exactly what you think they might, except : if you haven't ever seen a sequencing operator.  The : operator executes the code for the left-hand side of the expression followed by the code for the right-hand of side of the expression, and returns the result of the right-hand side.

One important thing to note is the precedence information specified at the top of *kparser.rb*.  This information is important to the parser, and will ensure that expressions get parsed the way you think they would.

	left :LT, :GT, :PIPE, :AMP, :SEQ, :EQL, :BANG, :NEG, :ELSE, :IN
	left :PLUS, :SUB
	right
	right :MUL, :DIV

The empty call to `right` causes the `:MUL` and `:DIV` symbols to hold the same precedence as `:PLUS` and `:SUB` symbols.  The `:NEG` symbol is created to give the unary minus production the correct precedence and associativity.

	clause('SUB e', :NEG)	{ |_, e| Sub.new(Number.new(0.0), e) }

## The Mandelbrot Set

Now that we have a language it's time to do something useful with it.  Specifically we are going to write some functions that will allow us to print out various [Mandelbrot sets](http://en.wikipedia.org/wiki/Mandelbrot_set).

First, we need to define our `putchard` helper function and use it to help us print out various values:

	extern putchard(char);

	def printdensity(d)
		if d > 8 then
			putchard(32)
		else if d > 4 then
			putchard(46)
		else if d > 2 then
			putchard(43)
		else
			putchard(42);

Next we define a function that determines how many iterations it takes a function to converge on the complex plane:

	# Determine whether the specific location diverges.
	# Solve for z = z^2 + c in the complex plane.
	def mandelconverger(real, imag, iters, creal, cimag)
		if iters > 255 | (real*real + imag*imag > 4) then
			iters
		else
			mandelconverger(real*real - imag*imag + creal,
				2*real*imag + cimag, iters + 1, creal, cimag);

	def mandelconverge(real, imag) mandelconverger(real, imag, 0, real, imag);

This "z = z2 + c" function is a beautiful little creature that is the basis for computation of the Mandelbrot Set.  Our mandelconverge function returns the number of iterations that it takes for a complex orbit to escape, saturating to 255.  This is not a very useful function by itself, but if you plot its value over a two-dimensional plane, you can see the Mandelbrot set.  Given that we are limited to using putchard here, our amazing graphical output is limited, but we can whip together something using the density plotter above:

	# Compute and plot the Mandlebrot set with the specified 2 dimensional range
	# info.
	def mandelhelp(xmin, xmax, xstep, ymin, ymax, ystep)
		for y = ymin, y < ymax, ystep in (
			(for x = xmin, x < xmax, xstep in
				printdensity(mandelconverge(x, y)))
			: putchard(10)
		);

	# mandel - This is a convenient helper function for plotting the Mandelbrot set
	# from the specified position with the specified magnification.
	def mandel(realstart, imagstart, realmag, imagmag)
		mandelhelp(realstart, realstart + realmag*78, realmag, imagstart,
			imagstart + imagmag*40, imagmag);

Once everything is defined inside the JIT we can print some Mandelbrot sets:

	Kazoo > mandel(-2.3, -1.3, 0.05, 0.07);
	******************************************************************************
	******************************************************************************
	****************************************++++++********************************
	************************************+++++...++++++****************************
	*********************************++++++++.. ...+++++**************************
	*******************************++++++++++..   ..+++++*************************
	******************************++++++++++.     ..++++++************************
	****************************+++++++++....      ..++++++***********************
	**************************++++++++.......      .....++++**********************
	*************************++++++++.   .            ... .++*********************
	***********************++++++++...                     ++*********************
	*********************+++++++++....                    .+++********************
	******************+++..+++++....                      ..+++*******************
	**************++++++. ..........                        +++*******************
	***********++++++++..        ..                         .++*******************
	*********++++++++++...                                 .++++******************
	********++++++++++..                                   .++++******************
	*******++++++.....                                    ..++++******************
	*******+........                                     ...++++******************
	*******+... ....                                     ...++++******************
	*******+++++......                                    ..++++******************
	*******++++++++++...                                   .++++******************
	*********++++++++++...                                  ++++******************
	**********+++++++++..        ..                        ..++*******************
	*************++++++.. ..........                        +++*******************
	******************+++...+++.....                      ..+++*******************
	*********************+++++++++....                    ..++********************
	***********************++++++++...                     +++********************
	*************************+++++++..   .            ... .++*********************
	**************************++++++++.......      ......+++**********************
	****************************+++++++++....      ..++++++***********************
	*****************************++++++++++..     ..++++++************************
	*******************************++++++++++..  ...+++++*************************
	*********************************++++++++.. ...+++++**************************
	***********************************++++++....+++++****************************
	***************************************++++++++*******************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************

	Kazoo > mandel(-2, -1, 0.02, 0.04);
	******************************************************************++++++++++++
	****************************************************************++++++++++++++
	*************************************************************+++++++++++++++++
	***********************************************************+++++++++++++++++++
	********************************************************++++++++++++++++++++++
	******************************************************++++++++++++++++++++++..
	***************************************************+++++++++++++++++++++......
	*************************************************++++++++++++++++++++.........
	***********************************************+++++++++++++++++++...       ..
	********************************************++++++++++++++++++++......        
	******************************************++++++++++++++++++++.......         
	***************************************+++++++++++++++++++++..........        
	************************************++++++++++++++++++++++...........         
	********************************++++++++++++++++++++++++.........             
	***************************++++++++...........+++++..............             
	*********************++++++++++++....  .........................              
	***************+++++++++++++++++....   .........   ............               
	***********+++++++++++++++++++++.....                   ......                
	********+++++++++++++++++++++++.......                                        
	******+++++++++++++++++++++++++........                                       
	****+++++++++++++++++++++++++.......                                          
	***+++++++++++++++++++++++.........                                           
	**++++++++++++++++...........                                                 
	*++++++++++++................                                                 
	*++++....................                                                     
		                                                                         
	*++++....................                                                     
	*++++++++++++................                                                 
	**++++++++++++++++...........                                                 
	***+++++++++++++++++++++++.........                                           
	****+++++++++++++++++++++++++.......                                          
	******+++++++++++++++++++++++++........                                       
	********+++++++++++++++++++++++.......                                        
	***********+++++++++++++++++++++.....                   ......                
	***************+++++++++++++++++....   .........   ............               
	*********************++++++++++++....  .........................              
	***************************++++++++...........+++++..............             
	********************************++++++++++++++++++++++++.........             
	************************************++++++++++++++++++++++...........         
	***************************************+++++++++++++++++++++..........

	Kazoo > mandel(-0.9, -1.4, 0.02, 0.03);
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	******************************************************************************
	****************************+++++++++++++++++*********************************
	***********************+++++++++++...++++++++++++*****************************
	********************+++++++++++++.. . .++++++++++++++*************************
	*****************++++++++++++++++... ......++++++++++++***********************
	**************+++++++++++++++++++...   .......+++++++++++*********************
	************++++++++++++++++++++....    .... ..++++++++++++*******************
	**********++++++++++++++++++++++......       ...++++++++++++******************
	********+++++++++++++++++++++++.......     .....++++++++++++++****************
	******++++++++++++++++++++++++.......      .....+++++++++++++++***************
	****+++++++++++++++++++++++++.... .         .....+++++++++++++++**************
	**+++++++++++++++++++++++++....                ...++++++++++++++++************
	*+++++++++++++++++++++++.......                ....++++++++++++++++***********
	+++++++++++++++++++++..........                .....++++++++++++++++**********
	++++++++++++++++++.............                .......+++++++++++++++*********
	+++++++++++++++................                ............++++++++++*********
	+++++++++++++.................                  .................+++++********
	+++++++++++...       ....                            ..........  .+++++*******
	++++++++++.....                                       ........  ...+++++******
	++++++++......                                                   ..++++++*****
	+++++++........                                                   ..+++++*****
	+++++..........                                                   ..++++++****
	++++..........                                                  ....++++++****
	++..........                                                    ....+++++++***
	..........                                                     ......+++++++**
	..........                                                      .....+++++++**
	..........                                                       .....++++++**
	.........                                                            .+++++++*
	........                                                             .+++++++*
	 ......                                                             ...+++++++
	   .                                                              ....++++++++
		                                                              ...++++++++
		                                                               ..++++++++

At this point, you may be starting to realize that Kazoo is a real and powerful language.  It may not be self-similar, but it can be used to plot things that are!

In the [next chapter](file.Chapter8.html), we will describe how you can add variable mutation to Kazoo without building SSA in your front-end. The full code listing for this chapter can be found in the "`examples/kazoo/chapter 7`" directory.
