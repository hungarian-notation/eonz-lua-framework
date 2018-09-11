# Eonz Lua Framework Project Outline

The goal of this project is to create a cross-platform cross-runtime lua
framework. We want to be able to run under Lua 5.1 (canonical 5.1, not luajit
pseudo-5.1) and beyond, as well as in any environment that uses an embedded
version of those systems.

## Expected API

This framework assumes that the following are defined in the global table and behave in a way that is
compatible with the Lua Reference Manual for the reported Lua version:

* `_G` global table
* `_VERSION` version string
* `assert`
* `error` that will accept arguments: `({string} message, {number} level)`
* `getmetatable`
* `ipairs`
* `next`
* `pairs`
* `rawequal`
* `rawget`
* `rawset`
* `require`
* `select`
* `setmetatable`
* `tonumber`
* `tostring`
* `type`
* either `unpack` or `table.unpack`
* `os.getenv` unless platform is manually specified
* `string` module with:
	* `string.byte`
	* `string.char`
	* `string.find`
	* `string.format`
	* `string.gmatch`
	* `string.gsub`
	* `string.len`
	* `string.lower`
	* `string.match`
	* `string.rep`
	* `string.reverse`
	* `string.sub`
	* `string.upper`
* `table` module with:
	* `table.concat`
	* `table.insert`
	* `table.remove`
	* `table.sort`

Modules that deal with IO or packages will also expect the io and package
loading API to be present. The behavior of those parts of this framework is
not defined if any of the following are missing:

* `pcall`
* `xpcall`
* `dofile`
* `load`
* `loadfile`
* `io` module with:
	* `io.close`
	* `io.flush`
	* `io.input`
	* `io.lines`
	* `io.open`
	* `io.output`
	* `io.popen`
	* `io.read`
	* `io.stderr`
	* `io.stdin`
	* `io.stdout`
	* `io.tmpfile`
	* `io.type`
	* `io.write`
	* `file:close`
	* `file:flush`
	* `file:lines`
	* `file:read`
	* `file:seek`
	* `file:setvbuf`
	* `file:write`
* `package` module with:
	* `package.config`, which while undocumented is present in Lua 5.1 and LuaJIT 2.x
	* `package.cpath`
	* `package.loaded`
	* `package.loaders` or `package.searchers`
	* `package.loadlib`
	* `package.path`
	* `package.preload`

Notably absent from these lists are `print` and the `debug` module. For print,
the `io` library will be used instead, and while the `debug` module may be
used to enhance error output in some places, its absence will be handled
gracefully and no core feature of this framework will rely on it. It is unstable
across versions and vms, and it is the first package to go as soon as an
embedded environment starts restricting the API.

## Graceful Degradation of Features

One of the core principles of this project is a graceful degradation of
features when the runtime environment is limited.

## Optional Features

`eonz.loadfile(path, env)` is available if one of the following criteria is met:

* `_G['setfenv']` is present, implying Lua 5.1
* Lua version is 5.2 or higher and `_G['loadfile']` is present.
* The framework detects that it is running under Luajit and `_G['loadfile']` is
present.
