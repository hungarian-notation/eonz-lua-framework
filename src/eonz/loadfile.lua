-- This module constructs an approximate equivalent loadfile across all
-- target lua versions. This resolves the incompatibility between Lua 5.1 and
-- Lua 5.2 caused by the change in the function environment system.
--
-- The version created when setfenv exists ignores the mode argument.

return function(file, env)
	if setfenv then
		return setfenv(loadfile(file), env)
	else
		return loadfile(file, nil, env)
	end
end
