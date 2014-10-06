# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/04/16
# Description:	This file defines the MemoryBuffer class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'

#######################
# Classes and Modules #
#######################

module RLTK::CG

	# This class is used by the {Module} class to dump and load LLVM bitcode.
	class MemoryBuffer
		include BindingClass

		# The Proc object called by the garbage collector to free resources used by LLVM.
		CLASS_FINALIZER = Proc.new { |id| Bindings.dispose_memory_buffer(ptr) if ptr = ObjectSpace._id2ref(id).ptr }

		# Create a new memory buffer.
		#
		# @param [FFI::Pointer, String, nil] overloaded This parameter may be either a pointer to an existing memory
		#   buffer, the name of a file containing LLVM bitcode or IR, or nil.  If it is nil the memory buffer will read
		#   from standard in.
		def initialize(overloaded = nil)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
			else
				buf_ptr = FFI::MemoryPointer.new(:pointer)
				msg_ptr = FFI::MemoryPointer.new(:pointer)

				status =
				case overloaded
				when String
					Bindings.create_memory_buffer_with_contents_of_file(overloaded, buf_ptr, msg_ptr)
				else
					Bindings.create_memory_buffer_with_stdin(buf_ptr, msg_ptr)
				end

				if status.zero?
					buf_ptr.get_pointer(0)
				else
					raise msg_ptr.get_pointer(0).get_string(0)
				end
			end

			# Define a finalizer to free the memory used by LLVM for this
			# memory buffer.
			ObjectSpace.define_finalizer(self, CLASS_FINALIZER)
		end

		# Get the size of the memory buffer.
		#
		# @return [Integer]  Size of memory buffer
		def size
			Bindings.get_buffer_size(@ptr)
		end

		# Get a copy of the memory buffer, from the beginning, as a sequence
		# of characters.
		#
		# @return [String]
		def start
			Bindings.get_buffer_start(@ptr)
		end
	end
end
