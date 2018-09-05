return function(file, mode, env)
	if setfenv then
		return setfenv(loadfile(file), env)
	else
		return loadfile(file, mode, env)
	end
end
