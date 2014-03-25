# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/05/21
# Description:	YARD extensions for documenting RLTK.  All of the current code
#			was taken from Jeremy Voorhis's project ruby-llvm, and credit
#			should go to him.

class RLTKTagFactory < YARD::Tags::DefaultFactory
	def parse_tag(name, text)
		case name
		when :LLVMInst then inst_tag(text)
		when :LLVMPass then pass_tag(text)
		else super
		end
	end
	
	private
	
	def inst_tag(text)
		url		= "http://llvm.org/docs/LangRef.html#i_#{text}"
		markup	= "<a href=\"#{url}\">LLVM Instruction: #{text}</a>"
		
		YARD::Tags::Tag.new('see', markup)
	end

	def pass_tag(text)
		url		= "http://llvm.org/docs/Passes.html##{text}"
		markup	= "<a href=\"#{url}\">LLVM Pass: #{text}</a>"
		
		YARD::Tags::Tag.new('see', markup)
	end
end

YARD::Tags::Library.define_tag 'Instruction', :LLVMInst
YARD::Tags::Library.define_tag 'Pass',        :LLVMPass
YARD::Tags::Library.default_factory = RLTKTagFactory
