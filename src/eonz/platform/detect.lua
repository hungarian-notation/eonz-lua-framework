local pf 	= require 'eonz.polyfill'
local table 	= pf.extended 'table'
local string	= pf.extended 'string'

return function (Platform)
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

			local parts = pf.string.split(Platform.capture('uname'), " \n", { empties = true });

			os_name = pf.string.trim(parts[1]):lower()
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
end
