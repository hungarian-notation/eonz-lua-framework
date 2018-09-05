local applied	= false
local applying	= false

return function(env)
	env = env or _G

	if applied then
		return -- do not attempt to apply the polyfills twice
	end

	if applying then
		error('recursive application of polyfill module')
	end

	-- Loads a polyfill implementation
	local function require_polyfill(name)
		return require('eonz.polyfill.detail.' .. tostring(name))
	end

	-- Applies a polyfill to the library "lib".
	local function apply_polyfill(id, base_lib)
		local polyfill = require_polyfill(id)

		local function apply_individual(polyfill, base_lib, multi)
			assert(type(polyfill['name']) == 'string')

			local pf_id

			if multi then
				pf_id = string.format("%s:%s", id, polyfill.name)
			else
				pf_id = id
			end

			if base_lib[polyfill.name] then
				error(string.format("base library already contains a method called \"%s\"", polyfill.name))
			else
				base_lib[polyfill.name] = polyfill.impl
				-- print(string.format("applied polyfill: %s", pf_id))
			end
		end

		if #polyfill == 0 then
			apply_individual(polyfill, base_lib, false)
		else
			for i, pf in ipairs(polyfill) do
				apply_individual(pf, base_lib, true)
			end
		end
	end

	apply_polyfill('string-polyfills', string)
	apply_polyfill('table-polyfills', table)

	applied		= true
	applying	= false
end
