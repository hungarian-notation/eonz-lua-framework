--[[
	Runtime is a standalone script that builds searchpaths at runtime.
	It will build the lua path for that application.
--]]

local rt = {}

function rt.debug(...)
	if EONZ_RT_DEBUG then
		print(...)
	end
end

function rt.invoke()
	rt.load_conf()
	return rt
end

function rt.external_package(...)
	local args = {...}

	local package_name, package_dir

	if #args == 2 then
		package_name 	= args[1]
		package_dir 	= args[2]
	elseif #args == 1 then
		package_dir 	= args[1]
		package_name 	= package_dir:match("^.+/([%a%d_]+)[/]?%s*$")
	end

	rt.load_package (package_name, package_dir)
end

function rt.local_package(package_name)
	local package_dir = rt.build_path(rt.package_path, package_name)
	rt.load_package (package_name, package_dir)
end

function rt.append_path(...)
	local addition = rt.path(...)
	rt.debug("appending to path:", addition)
	package.path = package.path .. ";" .. addition
end

function rt.load_package(package_name, package_dir)
	package_dir = rt.path(package_dir)

	local package_file = rt.path(package_dir, rt.PACKAGE_FILE)

	local pack = {
		name 	= package_name,
		home 	= package_dir
	}

	local package_file_env = {
		["_G"] 			= _G,
		["rt"] 			= rt,
		["package_name"]	= function (name) pack.name = name end,
		["package_info"]	= function (text) pack.info = text end,
		["package_path"]	= function (path)
			rt.create_package(pack, path)
		end
	}

	loadfile(package_file, "t", package_file_env)()
end

function rt.create_package(pack, package_path)
	if type(package_path) ~= 'table' then
		package_path = { package_path }
	end

	for i,path in ipairs(package_path) do
		package_path[i] = rt.path(pack.home, path)
	end

	pack.path = package_path

	rt.debug("creating package:", pack.name)

	for i,path in ipairs(pack.path) do
		rt.append_path(path, "?.lua")
		rt.append_path(path, "?", "init.lua")
	end

	rt.packages[pack.name] = pack

	if pack.name == "eonz-core" then
		rt.debug "registering with eonz core package"
		local eonz 	= require "eonz"
		eonz['RT'] 	= rt
	end
end

function rt.load_conf()
	local conf_path = rt.build_path(rt.package_path, rt.CONF_FILE)
	local conf_env = {
		["_G"] 			= _G,
		["rt"] 			= rt,
		["external_package"]	= rt.external_package,
		["local_package"]	= rt.local_package
	}
	loadfile(conf_path, "t", conf_env)()
end

function rt.path(...)
	local args = {...}
	if #args == 0 then return "." end
	local path = table.concat(args, "/")
	local normalized = path
	normalized = normalized:gsub("\\", 		"/")
	normalized = normalized:gsub("//", 		"/")
	normalized = normalized:gsub("/[.]/", 		"/")
	normalized = normalized:gsub("/[^/]+/[.][.]/", 	"/")
	return (normalized == path) and normalized or rt.path(normalized)
end

function rt.build_path(pattern, target)
	local path = string.gsub(pattern, "[?]", target)
	return rt.path(path)
end

rt.CONF_FILE	= "conf.lua"
rt.PACKAGE_FILE	= "package.lua"
rt.DEFAULT_PACKAGE_PATH = "./packages/?"

rt.package_path 	= (os and os.getenv and os.getenv("LUA_RT_PACKAGES"))
				or rt.DEFAULT_PACKAGE_PATH
rt.eonz_package 	= nil
rt.packages 		= {}

return rt.invoke()
