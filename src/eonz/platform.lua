require("eonz.polyfill")()

local WeightedAlternative 	= require "eonz.weighted-alternative"
local options			= require "eonz.options"

local Platform = {}

-- Platform will serve as the metatable for the returned value.
Platform.__index = Platform

local function parse_version_number(version_string)
	local parts = string.split(version_string, ".")

	if #parts == 1 then
		return { major = tonumber(parts[1]), minor = 0, revision = "" }
	elseif #parts >= 2 then
		local rev = ""
		if #parts > 2 then
			rev = table.concat(table.slice(parts, 3, -1), ".")
		end
		return { major = tonumber(parts[1]), minor = tonumber(parts[2]), revision = rev }
	else
		error("failed to parse lua version string")
	end
end

local function normalize_version(table)
	if type(table) ~= 'table' then
		local name = type(table) == 'string' and table or nil
		table = { name=name }
	end

	table.name 		= table.name or "Lua"
	table.name_token	= table.name:lower()
	table.major 		= table.major and tonumber(table.major) or 0
	table.minor 		= table.minor and tonumber(table.minor) or 0
	table.revision 		= table.revision or ""

	local has_revision = string.len(table.revision) > 0

	table.version_string 	= table.version_string or
		has_revision and string.format("%s %d.%d.%s", table.name, table.major, table.minor, table.revision)
		or string.format("%s %d.%d", table.name, table.major, table.minor)

	table.version_token = string.format("%s%d.%d", table.name_token, table.major, table.minor)

	return table
end

local function parse_version(version, number)
	local parts

	if version == nil then error('version was nil', 2) end

	if not number then
		parts = string.split(version, " ")

		if #parts == 1 then
			parts[2] = "0.0"
		end
	else
		parts = { version, number }
	end

	assert(#parts >= 2, "failed to parse version string")
	local version = parse_version_number(parts[2])
	version.name = parts[1]
	return normalize_version(version)
end

Platform.parse_version 		= parse_version
Platform.parse_version_number	= parse_version_number
Platform.normalize_version 	= normalize_version

Platform.vm_types = { 'lua', 'luajit', 'luaj'  }

function Platform.detect_framework()

	if type(_G['love']) == 'table' then
		return normalize_version {
			name = 'love',
			major = love._version_major,
			minor = love._version_minor,
			revision = love._version_revision
		}
	end

	return nil
end

function Platform.detect()

	local vm_type		= "unknown"
	local vm_version	= normalize_version()
	local lua_version	= normalize_version()

	if type(jit) == 'table' then

		vm 		= parse_version(jit.version)
		lua 		= parse_version(_VERSION)
		framework	= Platform.detect_framework()

	elseif type(luajava) == 'table' or (_VERSION and _VERSION:sub(1, 4):lower() == "luaj") then

		vm 		= parse_version(_VERSION)
		lua		= parse_version("Lua 5.2")
		env		= Platform.detect_framework()

	else

		vm 		= parse_version(_VERSION)
		lua		= parse_version(_VERSION)
		framework	= Platform.detect_framework()

	end

	return setmetatable({
		os = Platform.detect_os(),
		lua = lua,
		vm = vm,
		framework = framework,
		config = Platform.package_config()
	}, Platform)

end

function Platform.capture(command, opts)
	opts = opts or { string.split(tostring(opts)) }

	local output_raw 	= opts.raw or table.contains(opts, "raw") or false
	local output_lines 	= opts.lines or table.contains(opts, "lines") or false

	local f = assert(io.popen(command, 'r'))
	local s = assert(f:read('*a'))

	f:close()

	if output_raw then return s end

	s = string.trim(s)
	s = string.gsub(s, "[\r]?[\n]", "\n")

	return output_lines and string.split(s, "\n") or s
end

Platform.os_names = {
	'linux',
	'windows',
	'osx',
	'unknown'
}

function Platform.detect_os()
	local os_name 	 = "unknown"
	local os_version = nil

	if type(jit) ~= 'nil' then

		-- Use luajit builtins to get this value directly.
		os_name = jit.os:lower()

	elseif type(luajava) ~= 'nil' then

		-- Use luajava builtins to query the JVM for this value.
		local system = luajava.bindClass("java.lang.System")
		os_name = tostring(system:getProperty("os.name")):lower()

		-- We can also get os version directly here.
		os_version = parse_version(os_name, tostring(system:getProperty("os.version")))

	else

		local config 	= Platform.package_config()

		if config.directory == "\\" then
			os_name = "windows"
		else
			os_name = "unknown"
		end

	end

	os_name = tostring(os_name or 'unknown'):lower()

	if os_name == 'unknown' then
		-- In all cases, we should have been able to detect Windows.
		-- If the operating system is not windows, then it is either
		-- mac, linux, or unsupported. If it is one of the possible
		-- supported operating systems, the `uname` command should
		-- be available.

		-- TODO I don't have a mac to test this on.

		os_name = Platform.capture('uname'):split(" \n", { empties = true })[1]:trim():lower()
	end

	if not table.contains(Platform.os_names, os_name) then
		if os_name:lower():sub(1, 3) == 'mac' then
			os_name = 'osx'
		elseif os_name:lower():sub(1, 3) == 'win' then
			os_name = 'windows'
		else
			os_name = 'unknown'
		end
	end

	if os_name == 'linux' or os_name == 'osx' and not os_version then
		-- TODO better implementation?
		-- TODO can't find manpage for mac uname, does the -r flag
		-- 	give release version like it does on linux?

		os_version = parse_version(os_name, Platform.capture('uname -r'))
	end

	return normalize_version(os_name, os_version)
end

function Platform.package_config()
	local args = string.split(package.config, "\n")

	return {
		directory 	= args[1],
		path 		= args[2],
		substitution	= args[3],
		sub		= args[3],
		executable	= args[4],
		ignore		= args[5]
	}
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

local PathVariant = {} -- TODO unified class system
do PathVariant.__index = PathVariant
	function PathVariant.new(path, _, rest)
		return setmetatable({
			path 	= path,
			chain 	= rest
		}, PathVariant)
	end

	function PathVariant:debug()
		local bf = string.builder()

		for i = 1, #self.chain do
			if i ~= 1 then
				bf:append(", ")
			end

			bf:append(self.chain[i].s)
		end

		return string.format("{\"%s\" chain=[ %s ]}", self.path, tostring(bf))
	end

	function PathVariant.__lt(a, b)
		return WeightedAlternative.ascending_chains(a.chain, b.chain)
	end

	function PathVariant.__gt(a, b)
		return PathVariant.__lt(b, a)
	end

	function PathVariant.__le(a, b)
		return not PathVariant.__gt(a, b)
	end

	function PathVariant.__eq(a, b)
		if (getmetatable(a) ~= getmetatable(b)) then
			return false
		end
		assert(getmetatable(a) == PathVariant)
		return a.path == b.path
	end

	function PathVariant:__tostring()
		return self.path
	end

	setmetatable(PathVariant, {
		__call = function (type, ...) return type.new(...) end
	})
end

function Platform.expand(p, base, opts, ...)
	local variants = {}

	local args = {...}
	local plain_args = {}

	for i, arg in ipairs(args) do
		args[i] = arg
		plain_args[i] = tostring(args[i])
		assert(getmetatable(arg) == WeightedAlternative)
	end

	local dot_variant = table.concat(plain_args, ".")

	local exploded = p:explode_path(base)

	local function add(path)
		assert(getmetatable(path) == PathVariant)
		if not table.index(variants, path) then
			table.insert(variants, path)
		end
	end

	for i, part in ipairs(exploded) do
		if part == opts.expand then
			-- the expand operator forms an entire path component

			local parts = table.array_copy(exploded)
			local prefix = table.slice(parts, 1, i - 1)
			local suffix = table.slice(parts, i + 1, -1)

			local configurations = opts.preserve and {
				{score=2, config=table.join(args, {opts.expand})},
				{score=1, config=table.join({opts.expand}, args)},
			} or {{score=1, config=args}}

			for i, c in ipairs(configurations) do
				local path = p:path(table.join(prefix, c.config, suffix))
				add(PathVariant(path, c.score, args))
			end

			break
		elseif part:find(opts.expand, 1, true) then
			-- the expand operator forms part of a path component

			local parts = table.array_copy(exploded)

			if #args >= 1 then
				local modified = string.split(parts[i], opts.expand, { empties = true })
				local prefix = modified[1] or ""
				local suffix = modified[2] or ""

				parts[i] = prefix .. (opts.preserve and (opts.expand .. ".") or "") .. dot_variant .. suffix

				local path = p:path(parts)
				add(PathVariant(path, 100, args))
			end

			if opts.preserve and opts.directory then
				parts = table.array_copy(exploded)
				local path_prefix = table.slice(parts, 1, i - 1)
				local path_suffix = table.slice(parts, i, -1)

				local path = p:path(table.join(path_prefix, args, path_suffix))
				add(PathVariant(path, 10, args))
			end

			break
		end
	end

	if opts.passthrough and #variants == 0 then
		add(PathVariant(base, 0, args))
	end

	for i, variant in ipairs(variants) do
		assert(getmetatable(variant) == PathVariant)
	end

	return variants
end


function Platform.variants(p)

	local os_name		= p.os and WeightedAlternative( assert(p.os).name_token, 		1000 	)
	local any_os		= WeightedAlternative( "all",						500	)
	local framework_version	= p.framework and WeightedAlternative( p.framework.version_token,	150	)
	local vm_version	= p.vm and WeightedAlternative( assert(p.vm).version_token,		100	)
	local lua_version	= p.lua and WeightedAlternative( assert(p.lua).version_token,		75	)
	local framework_name 	= p.framework and WeightedAlternative( p.framework.name_token, 		55	)
	local vm_name 		= p.vm and WeightedAlternative( assert(p.vm).name_token,		50	)

	local alternatives = {}

	local term = WeightedAlternative

	local function add_basic(...)
		local args = {...}
		table.insert(alternatives, args)
	end

	local function add(...)
		add_basic(os_name, 	...)
		add_basic(any_os, 	...)
		add_basic(...)
	end

	add(vm_version)
	add(vm_name)
	add(lua_version)

	-- Build Variants
	if p.framework then
		add(framework_version)
		add(framework_name)
	end

	add()

	table.sort(alternatives, WeightedAlternative.descending_chains)

	--[[
	print("------------")

	for i,alt in ipairs(alternatives) do
		print(i, table.tostring(alt))
	end
	--]]

	return alternatives
end

local function path_variant_ordering(great_base)
	return function(a, b)
		local difference = WeightedAlternative.chain_difference(a.chain, b.chain)

		if difference < 0 then
			return false
		elseif difference > 0 then
			return true
		else
			return false
		end

	end
end

function Platform.expand_paths(p, search_path, opts)
	opts = options.from(opts, {
		expand 		= p.config.substitution,
		passthrough	= true,
		preserve 	= 'defer',
		directory	= 'defer',
		variants	= p:variants()
	})

	if opts.preserve == 'defer' then
		opts.preserve = opts.expand == p.config.substitution
	end

	if opts.directory == 'defer' then
		opts.directory = opts.expand == p.config.substitution
	end

	local new_path = {}

	local function add(path)
		if not table.index(new_path, path) then
			table.insert(new_path, path)
		end
	end

	local function add_variant(base, ...)
		local variants = p:expand(p:path(base), opts, ...)

		for i, variant in ipairs(variants) do
			add(variant)
		end
	end

	local variants = opts.variants

	for i, path in ipairs(string.split(search_path, p.config.path)) do
		for j, variant in ipairs(variants) do
			add_variant(path, unpack(variant))
		end
	end

	table.stable_sort(new_path, path_variant_ordering(true))

	local plain_paths = {}


	--[[
		print()
		print()
		print("---")
	--]]
	for i, path in ipairs(new_path) do
		plain_paths[i] = tostring(path)
		--print(path:debug())
	end
	--[[
		print("---")
		print()
	--]]

	return table.concat(plain_paths, p.config.path)
end

function Platform:search_path(opts)
	opts = options.from(opts, {
		roots = { "." },
		stubs = {
			self:path("?.*.lua"),
			self:path("*", "?.lua"),
			self:path("?", "init.*.lua"),
			self:path("*", "?", "init.lua"),
		}
	})

	local fragments = {}

	for i,root in ipairs(opts.roots) do
		for j, stub in ipairs(opts.stubs) do
			table.insert(fragments, self:path(self:path(root), self:path(stub)))
		end
	end

	fragments = self:paths (fragments)
	return self:expand_paths (fragments, { expand="*", passthrough=false })
end

return Platform
