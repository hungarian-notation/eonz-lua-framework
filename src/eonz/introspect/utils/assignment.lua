local eonz 		= require 'eonz'
local support 		= require 'eonz.introspect.utils.scope.support'
local Value 		= require 'eonz.introspect.utils.value'
local Variable 		= require 'eonz.introspect.utils.variable'
local ValueReference 	= require 'eonz.introspect.utils.value_reference'

local Assignment = eonz.class { name = "eonz::introspect::Assignment", extends = ValueReference }
do
	function Assignment:init(opt)
		Assignment:__super { self, opt }
		self._assigned 	= assert(opt.assigned_value);

		assert(self:object():get_class() ~= ValueReference)
	end

	function Assignment:assigned_value()
		return self._assigned
	end

	function Assignment:display()
		return self:object():display() .. " = (" .. self:assigned_value():display() .. ")"
	end

	Assignment.__tostring = Assignment.display
end

return Assignment
