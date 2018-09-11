-- luajit implements the 5.2 loadfile extension while reporting a lua version
-- of 5.1

return function(path, env)
	return loadfile(path, nil, env)
end
