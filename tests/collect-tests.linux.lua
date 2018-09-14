return function()
	local pf 	= require 'eonz.polyfill'
	local command 	= io.popen([[find ./*/* -type f -name test-*.lua]])
	local line
	local tests 	= {}

	repeat
		line = command:read('*l')
		if line then
			local parts = pf.string.split(line, "/")

			assert(#parts > 1)
			assert(type(parts[1] == 'string'))
			assert(parts[1] == ".")
			assert(parts[#parts]:sub(-4, -1) == ".lua")

			parts[#parts] = parts[#parts]:sub(1, -5)
			parts = pf.table.slice(parts, 2, -1)
			test_group = pf.table.concat(parts, ".")
			pf.table.insert(tests, { group = test_group, path = line })
		end
	until not line

	command:close()
	return tests
end
