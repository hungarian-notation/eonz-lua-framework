local WeightedAlternative 	= require 'eonz.weighted_alternative'
local options			= require 'eonz.options'
local unpack			= require 'eonz.unpack'

return function(Platform)

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
end
