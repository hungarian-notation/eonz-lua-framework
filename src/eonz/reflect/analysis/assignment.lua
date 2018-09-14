local eonz 		= require 'eonz'
local support 		= require 'eonz.reflect.analysis.scope.support'
local Value 		= require 'eonz.reflect.analysis.value'
local Variable 		= require 'eonz.reflect.analysis.variable'
local ValueReference 	= require 'eonz.reflect.analysis.value_reference'

local Assignment = eonz.class { name = "eonz::reflect::Assignment", extends = ValueReference }
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
