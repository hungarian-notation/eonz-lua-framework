local pf	= require "eonz.polyfill"
local table 	= pf.extended 'table'
local string	= pf.extended 'string'

-- NOTE: This module is a dependency of `eonz.platform` and will be loaded
-- before the cross-platform path system is initialized. It must be entirely
-- platform agnostic.

local WeightedAlternative = require('eonz.objects').class "WeightedAlternative"
do
	function WeightedAlternative:__tostring()
		return tostring(self.t):lower()
	end

	function WeightedAlternative.__eq(a, b)
		return a.s == b.s and a.t == b.t
	end

	function WeightedAlternative.__lt(a, b)
		return a.s < b.s or ((a.s == b.s) and (a.t < b.t))
	end

	function WeightedAlternative.__le(a, b)
		return WeightedAlternative.__eq(a, b) or WeightedAlternative.__lt(a, b)
	end

	function WeightedAlternative.new(term, specificity)
		return setmetatable({t=term, s=specificity or 1}, WeightedAlternative)
	end

	setmetatable(WeightedAlternative, {
		__call = function (type, ...) return type.new(...) end
	})

	-- static utilities
	function WeightedAlternative.ascending_chains(a, b)
		-- Returns true if alternative A is less specific than
		-- alternative B

		local av = (a and a[1]) or nil
		local bv = (b and b[1]) or nil

		if av == nil and bv ~= nil then
			return true
		elseif bv == nil then
			-- This captures a == b == nil and a ~= nil && b == nil,
			-- which is valid because in both cases a is not
			-- less specific than b
			return false
		end

		assert(type(av) == 'table')
		assert(type(bv) == 'table')

		if av < bv then
			return true
		elseif  av > bv then
			return false
		else
			return WeightedAlternative.ascending_chains(table.slice(a, 2, -1), table.slice(b, 2, -1))
		end
	end

	function WeightedAlternative.descending_chains(a, b)
		return WeightedAlternative.ascending_chains(b, a)
	end

	function WeightedAlternative.chain_difference(a, b)
		if WeightedAlternative.ascending_chains(a, b) then
			return -1
		elseif WeightedAlternative.descending_chains(a, b) then
			return 1
		else
			return 0
		end
	end
end

return WeightedAlternative
