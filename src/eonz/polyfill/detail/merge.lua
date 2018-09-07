-- This is split out from the main polyfill class for use in eonz.options which
-- may occur prior to the completion of the polyfill module's execution. It
-- should not be required by any other external module without modifying this
-- notice.

return function (t, ...)
	local tables = {...}

	for i, m in ipairs(tables) do
		for k, v in pairs(m) do
			t[k] = v
		end
	end

	return t
end
