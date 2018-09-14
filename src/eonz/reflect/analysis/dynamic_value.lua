local eonz = require 'eonz'
local table = eonz.pf.table

local Value = require "eonz.reflect.analysis.value"

local DynamicValue = eonz.class { name="eonz::reflect::DynamicValue", extends=Value }
do
	function DynamicValue:init(opt)
		opt = opt or {}

		opt.dynamic = true;
		DynamicValue:__super { self, opt }

		self._category	= opt.category or opt.dynamic_category or 'value'
	end

	function DynamicValue:dynamic_category()
		return self._category
	end

	function DynamicValue:display()
		return ((self:known_type() and "«"
			.. self:value_type()
			.. " " or "«dynamic ")
			.. self:dynamic_category()
			.. "»")
	end

	function DynamicValue:__tostring()
		return self:display()
	end
end

return DynamicValue
