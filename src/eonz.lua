local EONZ = {}
local EONZ_METATABLE = {}

function EONZ.debug(...)
	if EONZ_DEBUG then
		print(...)
	elseif EONZ.RT then
		EONZ.RT.debug(...)
	end
end

function EONZ.configure(opt)

	require('eonz.polyfill')()

	-- TODO: actual global polyfill should not be required for the core
	-- library to function. The EONZ.lib value should be a polyfilled
	-- version of the standard library, but the modification of the actual
	-- global table should be optional and configurable.

	EONZ.table 	= table
	EONZ.string	= string
	EONZ.package	= package
	EONZ.io		= io
	EONZ.math	= math

	EONZ.options 	= require 'eonz.options'
	EONZ.objects 	= require 'eonz.objects'
	EONZ.class	= EONZ.objects.class
	EONZ.get_class	= EONZ.objects.get_class

	EONZ.platform 	= require('eonz.platform'):detect()

	opt = EONZ.options.from(opt, {
		configure_path 	= true,
		path_roots 	= nil,
		path_stubs 	= nil,
		export_global 	= false,
	})

	if opt.configure_path then

		if not opt.path_roots then
			opt.path_roots = {}

			local on_path = platform.explode_paths()
		end

		local p 	= EONZ.platform
		local roots 	= table.copy(opt.path_roots or {})

		if EONZ.RT then
			EONZ.debug "expanding package roots"
			for _, pack in pairs(EONZ.RT.packages) do
				for i, root in ipairs(pack.path) do
					root = p:normalize(root, "")
					EONZ.debug("  found: " .. root)
					table.insert(roots, root)
				end
			end
		end

		package.path = EONZ.platform:paths {
			EONZ.platform:search_path({
				roots = roots
			})
		}
	end

	if opt.export_global then
		_G['eonz'] = EONZ
	end

	EONZ.__index = EONZ.__runtime_index

	return EONZ.INSTANCE
end

function EONZ_METATABLE.__call(EONZ, ...)
	return EONZ.configure(...)
end

EONZ.__call = EONZ_METATABLE.__call

function EONZ.__index(host, key)
	-- this index function is unset after the eonz module
	-- is configured and replaced with __runtime_index

	if key == 'configure' then
		return EONZ.configure
	else
		error('eonz library not configured')
	end
end

function EONZ.hotload(key)
	EONZ[key] = require("eonz." .. key)
	return EONZ[key]
end

function EONZ.__runtime_index(host, key)
	return EONZ[key] or EONZ.hotload(key)
end

EONZ.INSTANCE = setmetatable({}, setmetatable(EONZ, EONZ_METATABLE))

return EONZ.INSTANCE
