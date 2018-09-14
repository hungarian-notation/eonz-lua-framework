local eonz 	= require 'eonz'
local support 	= require 'eonz.reflect.analysis.scope.support'
local Value 	= require 'eonz.reflect.analysis.value'
local Variable 	= require 'eonz.reflect.analysis.variable'

local ValueReference = eonz.class { name = "eonz::reflect::ValueReference", extends = Value }
do
	function ValueReference:init(opt)
		ValueReference:__super { self, opt }

		self._what 		= assert(opt.object or opt.what or opt.target)
		self._of_variable	= self._what:get_class() == Variable

		self:register()
	end

	function ValueReference:register()
		self:object():add_reference(self)
	end

	-- Used to delete a reference when it is superseded by a more
	-- specific interaction.
	function ValueReference:delete()
		self:object():remove_reference(self)
	end

	function ValueReference:object()
		return self._what
	end

	function ValueReference:variable()
		return self._of_variable and self._what
	end

	function ValueReference:display()
		--if self:variable() and self:variable():category() == 'local' then
		--	return self:object():display() .. " " .. string.format("(assigned from %d location(s))", #self:object():assignments())
		--else
			return self:object():display()
		--end
	end

	ValueReference.__tostring = ValueReference.display
end

return ValueReference
