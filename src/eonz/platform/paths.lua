local pf	= require "eonz.polyfill"
local table 	= pf.extended 'table'
local string	= pf.extended 'string'

return function(Platform)
	-- This module should not be required directly, it is a component of
	-- eonz.platform and is included in that module.

	function Platform.is_absolute(p, path)
		local parts = p:explode_path(path)

		if p.os and p.os.name == 'windows' then
			-- match drive letter for windows
			return #parts >= 1 and (string.match(parts[1], "[%a][:]") ~= nil)
		else
			-- on all other systems, look for leading "/" which will
			-- present here as a zero-length part in the first index
			return #parts > 1 and parts[1] == ""
		end
	end

	local function path_reduction_pass(p, parts)
		for i = 1, #parts - 1 do
			local this = parts[i]
			local next = parts[i + 1]

			if next == "." then
				table.remove(parts, i + 1)
				return true
			end

			if next == ".." then
				table.remove(parts, i + 1)
				table.remove(parts, i)
				return true
			end

			if next == "" then
				table.remove(parts, i + 1)
				return true
			end
		end

		return false
	end

	local function path_reduce(p, parts)
		local reduced = false
		repeat
			reduced = path_reduction_pass(p, parts)
		until not reduced
		return parts
	end

	function Platform.normalize_path(p, ...)
		local absolute	= p:is_absolute(p:path(...))
		local parts	= p:explode_path(...)

		if not absolute then table.insert(parts, 1, ".") end

		parts 		= path_reduce(p, parts)
		return table.concat(parts, p.config.directory)
	end

	Platform.normalize = Platform.normalize_path

	function Platform.explode_paths(p, ...)
		local args = {...}

		if #args == 1 and type(args[1]) == 'table' then
			args = args[1]
		end

		local parts = {}

		for i, arg in ipairs(args) do
			local segments = string.split(tostring(arg), tostring(p.config.path), { empties = false })

			for j, seg in ipairs(segments) do
				table.insert(parts, seg)
			end
		end

		return parts
	end

	function Platform.explode_path(p, ...)
		local args = {...}

		if #args == 1 and type(args[1]) == 'table' then
			args = args[1]
		end

		local parts = {}

		for i, arg in ipairs(args) do
			local segments = string.split(tostring(arg), tostring(p.config.directory) .. "/\\", { empties = true })

			for j, seg in ipairs(segments) do
				table.insert(parts, seg)
			end
		end

		return parts
	end

	function Platform.path(p, ...)
		return table.concat(p:explode_path(...), p.config.directory)
	end

	function Platform.paths(p, ...)
		local args = {...}

		if #args == 1 and type(args[1]) == 'table' then
			args = args[1]
		end

		return table.concat(args, p.config.path)
	end
end
