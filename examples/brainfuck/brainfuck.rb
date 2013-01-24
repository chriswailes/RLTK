#!/usr/bin/ruby

############
# Requires #
############

# Standard library requires
require 'pp'

# RLTK requires
require 'rltk/lexer'
require 'rltk/parser'
require 'rltk/ast'
require 'rltk/cg/contractor'
require 'rltk/cg/execution_engine'

module Brainfuck
	DATA_SIZE = 20
	
	class Lexer < RLTK::Lexer
		r(/>/)	{ :PTRRIGHT }
		r(/</)	{ :PTRLEFT  }
		r(/\+/)	{ :INC      }
		r(/-/)	{ :DEC      }
		r(/\./)	{ :PUT      }
		r(/,/)	{ :GET      }
		r(/\[/)	{ :LBRACKET }
		r(/\]/)	{ :RBRACKET }
		
		r /[^\[\]\-+,.<>]/
	end
	
	class Operation < RLTK::ASTNode; end
	
	class PtrRight  < Operation; end
	class PtrLeft   < Operation; end
	class Increment < Operation; end
	class Decrement < Operation; end
	class Put       < Operation; end
	class Get       < Operation; end
	
	class Loop < Operation
		child :body, [Operation]
	end
	
	class Program < RLTK::ASTNode
		child :body, [Operation]
	end
	
	class Parser < RLTK::Parser
		
		p(:program, 'ops') { |ops| Program.new(ops) }
		
		p :ops do
			c('op')		{ |o| [o] }
			c('ops op')	{ |os, o| os + [o] }
		end
		
		p :op do
			c('PTRRIGHT')				{ |_| PtrRight.new          }
			c('PTRLEFT')				{ |_| PtrLeft.new           }
			c('INC')					{ |_| Increment.new         }
			c('DEC')					{ |_| Decrement.new         }
			c('PUT')					{ |_| Put.new               }
			c('GET')					{ |_| Get.new               }
			c('LBRACKET ops RBRACKET')	{ |_, ops, _| Loop.new(ops) }
		end
		
		finalize explain: 'brainfuck.tbl'
	end
	
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
			
			# Grab a reference to the putchar function.
			@putchar = @module.funs.add('putchar', CG::NativeIntType, [CG::NativeIntType])
		end
		
		def curr_cell
			gep @data, [load(@offset)]
		end
		
		def curr_val
			load curr_cell
		end
		
		on Program do |prog|
			fun = @module.funs.add('BF', CG::NativeIntType, [])
			
			init_loop = fun.blocks.append('init loop')
			init_body = fun.blocks.append('init body')
			body		= fun.blocks.append('body')
			
			build fun.blocks.append('entry') do
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
				
				puts 'Generating the body.'
				
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
		
		on(Brainfuck::PtrRight)	{ puts 'PtrRight'; store (add (load @offset), ONE), @offset }
		on(Brainfuck::PtrLeft)	{ puts 'PtrLeft'; store (sub (load @offset), ONE), @offset }
		on(Brainfuck::Increment)	{ puts 'Increment'; store (add curr_val, ONE), curr_cell }
		on(Brainfuck::Decrement)	{ puts 'Decrement'; store (sub curr_val, ONE), curr_cell }
		on(Brainfuck::Put)		{ puts 'Put'; call @putchar, curr_val }
		
		on Get do
			raise 'Shit!'
		end
		
		on Loop do |l|
			puts 'Loop'
			
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

jit = Brainfuck::JIT.new

if ARGV[0]
	raise "No such file exists: #{ARGV[0]}" if not File.exists?(ARGV[0])
	
	jit.visit Brainfuck::Parser.parse(Brainfuck::Lexer.lex_file(ARGV[0]))
else
	loop do
		print('Brainfuck: ')
		line = ''
	
		begin
			line += ' ' if not line.empty?
			line += $stdin.gets.chomp
		end while line[-1,1] != ';'
		
		line = line[0..-2]
	
		if line == 'quit;' or line == 'exit;'
			jit.module.verify
			jit.module.dump
		
			break
		end
	
		begin
			tokens = Brainfuck::Lexer.lex(line)
			pp tokens
			
			ast = Brainfuck::Parser.parse(tokens, verbose: true)
			pp ast
			
			jit.visit ast
			
	
		rescue Exception => e
			puts e.message
			puts e.backtrace
			puts
	
		rescue RLTK::LexingError, RLTK::NotInLanguage
			puts 'Line was not in language.'
		end
	end
end
