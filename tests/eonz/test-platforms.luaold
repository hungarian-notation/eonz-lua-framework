
local PlatformType = require "eonz.platform"

local function mock_package_config(...)
	local args = {...}
	return {
		directory 	= args[1],
		path 		= args[2],
		substitution	= args[3],
		sub		= args[3],
		executable	= args[4],
		ignore		= args[5]
	}
end

local function mock_unix_config()
	return mock_package_config("/", ";", "?", "!", "-")
end

local function mock_windows_config()
	return mock_package_config("\\", ";", "?", "!", "-")
end

local function mock_platform(os, lua, vm, framework, config)

	os = os and PlatformType.parse_version(os)

	return setmetatable({
		os 		= os,
		lua 		= lua and PlatformType.parse_version(lua),
		vm 		= vm and PlatformType.parse_version(vm),
		framework 	= framework and PlatformType.parse_version(framework) or nil,
		config 		= config or ((os and os.name:lower() == 'windows') and mock_windows_config() or mock_unix_config())
	}, PlatformType)
end

tests["platform:is_absolute(path)"] = function()

	local posix 	= mock_platform("linux")
	local windows 	= mock_platform("windows")

	local expected_posix_true = {
		"/home/root/secrets",
		"/usr/bin",
		"/etc",
		"/",
		"/home/user/Desktop/Cat Pictures"
	}

	local expected_posix_false = {
		"./src",
		[[C:\Users\Admin\Desktop\Better Cat Pictures]],
		".",
		"../hello/world",
		"src",
		"hello/world/"
	}

	local expected_windows_true = {
		[[C:\Users\Admin\Desktop\Cat Pictures]],
		[[c:\Users\]],
		[[c:\Users\..\Windows\]],
		[[C:\]],
		[[C:]],
		[[D:\autorun.bat]],
		[[F:\Backups\Pictures of Dogs]],
	}

	local expected_windows_false = {
		"./src",
		".",
		"../hello/world",
		"src",
		"hello/world/",
		"/home/root/secrets",
		"/usr/bin",
		"/etc",
		"/",
		"/home/user/Desktop/Cat Pictures"
	}

	for i, path in ipairs(expected_posix_true) do
		assert_true(posix:is_absolute(path))
	end

	for i, path in ipairs(expected_posix_false) do
		assert_false(posix:is_absolute(path))
	end

	for i, path in ipairs(expected_windows_true) do
		assert_true(windows:is_absolute(path))
	end

	for i, path in ipairs(expected_windows_false) do
		assert_false(windows:is_absolute(path))
	end

end

tests["platform:path(...) path joining"] = function()
	local platform = mock_platform("linux")

	assert_equal( "./hello/linux.x", platform:path (".", "hello", "linux.x") )
	assert_equal( "./hello/linux.x", platform:path ({".", "hello", "linux.x"}) )
	assert_equal( "/hello/linux.x", platform:path ("", "hello", "linux.x") )
end

tests["platform:normalize_path(...) path joining"] = function()
	local linux 	= mock_platform("linux")

	local tests = {
		{ "./hello///../src", 				"./src" 				},
		{ "././././hello/goodbye/..", 			"./hello" 				},
		{ "\\home\\idiot\\why-windows-rox.docx", 	"/home/idiot/why-windows-rox.docx" 	},
		{ "src///", 					"./src" 				},
		{ "src/some/file.lua", 				"./src/some/file.lua" 			},
	}

	for i, pair in ipairs(tests) do
		assert_equal(pair[2], 	linux:normalize_path(pair[1]))
	end
end

tests["platform:normalize_path(...) windows"] = function()
	local windows 	= mock_platform("windows")

	local tests = {
		{ "\\Pictures\\Pictures of Dogs\\", 			".\\Pictures\\Pictures of Dogs"	},
		{ "C:\\Windows\\..\\Users\\Admin\\Desktop\\\\\\", 	"C:\\Users\\Admin\\Desktop" 	},
		{ "\\Pictures\\Pictures of Dogs\\..\\",			".\\Pictures" 			},
	}

	for i, pair in ipairs(tests) do
		assert_equal(pair[2], 	windows:normalize_path(pair[1]))
	end
end

tests["platform.normalize == platform.normalize_path"] = function()
	assert_same(PlatformType.normalize, PlatformType.normalize_path)
end

tests["platform.explode_paths()"] = function()
	local linux 	= mock_platform("linux")

	local paths = { "a;b;././c/d;", "?.lua", ";;;", "." }

	local expected = {
		"a",
		"b",
		"././c/d",
		"?.lua",
		"."
	}

	assert_table_equals(expected, linux:explode_paths( paths               ))
	assert_table_equals(expected, linux:explode_paths( table.unpack(paths) ))
end

function test.search_path__directory__os_only()
	local platform = mock_platform("linux")

	local path_string = platform:search_path {
		roots = { "." },
		stubs = { "*/?.x" }
	}

	local paths = string.split(path_string, ";")

	assert_equals(3, #paths)
	assert_equals("./linux/?.x", 	paths[1])
	assert_equals("./all/?.x", 	paths[2])
	assert_equals("./?.x", 	paths[3])
end

function test.search_path__file__os_only()
	local platform = mock_platform("linux")

	local path_string = platform:search_path {
		roots = { "." },
		stubs = { "?.*.x" }
	}

	local paths = string.split(path_string, ";")

	assert_equals(2, #paths)
	assert_equals("./?.linux.x", 	paths[1])
	assert_equals("./?.all.x", 	paths[2])
end

test['search_path, os only, directory only, multiple roots'] = function()
	local platform = mock_platform("linux")

	local path_string = platform:search_path {
		roots = { "/a", {".", "b"} },
		stubs = { "*/?.x" }
	}

	local paths = string.split(path_string, ";")

	--print()
	--print(table.tostring(paths))

	assert_equals(6, #paths)
	assert_equals("/a/linux/?.x", 	paths[1])
	assert_equals("./b/linux/?.x", 	paths[2])
	assert_equals("/a/all/?.x", 	paths[3])
	assert_equals("./b/all/?.x", 	paths[4])
	assert_equals("/a/?.x",		paths[5])
	assert_equals("./b/?.x",	paths[6])
end

function test.search_path__file()
	local platform = mock_platform("linux", "lua 5.3")

	local path_string = platform:search_path {
		roots = { "." },
		stubs = { "?.*.x" }
	}

	local paths = string.split(path_string, ";")

	--print()
	--print(table.tostring(paths))

	assert_equals(5, #paths)
	assert_equals("./?.linux.lua5.3.x", 	paths[1])
	assert_equals("./?.linux.x", 		paths[2])
	assert_equals("./?.all.lua5.3.x", 	paths[3])
	assert_equals("./?.all.x", 		paths[4])
	assert_equals("./?.lua5.3.x", 	paths[5])
end

function test.search_path__mixed()
	local platform = mock_platform("linux", "lua 5.3")

	local path_string = platform:search_path {
		roots = { "." },
		stubs = {
			"?.*.x",
			"*/?.x"
		}
	}

	local paths = string.split(path_string, ";")

	--print()
	--print(table.tostring(paths, {pretty = true}))


	assert_equals(11, #paths)
	assert_equals("./?.linux.lua5.3.x", 	paths[1])
	assert_equals("./linux/lua5.3/?.x", 	paths[2])
	assert_equals("./?.linux.x", 		paths[3])
	assert_equals("./linux/?.x", 		paths[4])
	assert_equals("./?.all.lua5.3.x", 	paths[5])
	assert_equals("./all/lua5.3/?.x", 	paths[6])
	assert_equals("./?.all.x", 		paths[7])
	assert_equals("./all/?.x", 		paths[8])
	assert_equals("./?.lua5.3.x", 	paths[9])
	assert_equals("./lua5.3/?.x", 	paths[10])
	assert_equals("./?.x", 		paths[11])
end

function test.search_path__directory()
	local platform = mock_platform("linux", "lua 5.3")

	local path_string = platform:search_path {
		roots = { "." },
		stubs = { "*/?.x" }
	}

	local paths = string.split(path_string, ";")

	assert_equals(6, #paths)
	assert_equals("./linux/lua5.3/?.x", 	paths[1])
	assert_equals("./linux/?.x", 		paths[2])
	assert_equals("./all/lua5.3/?.x", 	paths[3])
	assert_equals("./all/?.x", 		paths[4])
	assert_equals("./lua5.3/?.x", 	paths[5])
	assert_equals("./?.x", 		paths[6])
end
