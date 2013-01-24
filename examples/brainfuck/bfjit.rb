############
# Requires #
############

# Standard library requires
require 'pp'

# RLTK requires
require 'rltk/cg/contractor'
require 'rltk/cg/execution_engine'

# Project requires
require './bfparser'

module Brainfuck
	DATA_SIZE = 1000
	
	RLTK::CG::LLVM.init(:x86)
	
	class JIT < RLTK::CG::Contractor
		include RLTK
		
		ZERO = CG::NativeInt.new(0)
		ONE	= CG::NativeInt.new(1)
		
		def initialize
			super
			
			# This LLVM Module object is where our functions will go.
			@module = CG::Module.new('Brainfuck JIT')
			
			# This is what will compile/execute our code.
			@engine = CG::JITCompiler.new(@module)
			
			# Add passes to the Function Pass Manager.
			@module.fpm.add(:PromoteMemToReg, :InstCombine, :Reassociate, :ConstProp, :ADCE, :DSE)
			
			# Grab a reference to the putchar and getchar functions.
			@putchar = @module.funs.add('putchar', CG::NativeIntType, [CG::NativeIntType])
			@getchar = @module.funs.add('getchar', CG::NativeIntType, [])
		end
		
		def curr_cell
			gep @data, [load(@offset)]
		end
		
		def curr_val
			load curr_cell
		end
		
		on Program do |prog|
			fun = @module.funs.add('BF', CG::NativeIntType, [])
			
			entry	= fun.blocks.append('entry')
			init_loop = fun.blocks.append('init loop')
			init_body = fun.blocks.append('init body')
			body		= fun.blocks.append('body')
			
			build entry do
				@offset	= alloca CG::NativeIntType
				@data	= array_alloca CG::NativeIntType, CG::NativeInt.new(DATA_SIZE)
				
				store ZERO, @offset
				
				br init_loop
			end
			
			build init_loop do
				loop_cond = icmp :eq, (load @offset), CG::NativeInt.new(DATA_SIZE)
				
				cond loop_cond, body, init_body
			end
			
			build init_body do
				addr = gep(@data, [load(@offset)])
				
				store ZERO, addr
				
				store (add (load @offset), ONE), @offset
				
				br init_loop
			end
			
			build body do
				store CG::NativeInt.new(DATA_SIZE/2), @offset
				
				prog.body.each { |n| visit n }
				
				ret ZERO
			end
			
			# Verify the function
			fun.verify!
			
			# Optimize the function
			@module.fpm.run(fun)
			
			# Execute the function
			@engine.run_function(fun)
		end
		
		on(Brainfuck::PtrRight)	{ store (add (load @offset), ONE), @offset }
		on(Brainfuck::PtrLeft)	{ store (sub (load @offset), ONE), @offset }
		on(Brainfuck::Increment)	{ store (add curr_val, ONE), curr_cell     }
		on(Brainfuck::Decrement)	{ store (sub curr_val, ONE), curr_cell     }
		on(Brainfuck::Put)		{ call @putchar, curr_val                  }
		on(Get)				{ store (call @getchar), curr_cell         }
		
		on Loop do |l|
			fun = current_block.parent
			
			loop_head = fun.blocks.append('loop head')
			loop_body = fun.blocks.append('loop body')
			loop_next = fun.blocks.append('loop next')
			
			br loop_head
			
			build loop_head do
				loop_cond = icmp :eq, curr_val, ZERO
				
				cond loop_cond, loop_next, loop_body
			end
			
			build loop_body do
				l.body.each { |n| visit n }
				
				br loop_head
			end
			
			target loop_next
		end
	end
end
