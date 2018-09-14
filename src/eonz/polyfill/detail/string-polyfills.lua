--[[
	The function returned by this file implements a basic string splitting
	algorithm that breaks up a string at individual delimiter characters.
--]]

local unpack = require "eonz.unpack"

local function split_impl(str, sep, opt)
	options = require('eonz.options').from(opt, {
		max = -1
	})

	sep = sep or ",;\t\n"

	if type(str) == 'nil' then
		error("input string must not be nil")
	end

	if type(str) ~= 'string' then
		error('expected string input text as argument #1 (got \"' .. tostring(str) .. '\")',2)
	end

	if type(sep) ~= 'string' then
		error('expected string input text as argument #2 (got \"' .. tostring(sep) .. '\")',2)
	end

	local parts = {}
	local part = ""

	local function test(char)
		if #parts == options.max - 1 then
			return false, true
		end

		if sep == "" then
			return true, true
		end

		for i = 1, string.len(sep) do
			if char == sep:sub(i,i) then
				return true, options.keep and true
			end
		end

		return false, true
	end

	local function collect()
		if string.len(part) > 0 or options.empties then
			parts[#parts + 1] = tostring(part)
		end
		part = ""
	end

	for i = 1, string.len(str) do
	  local char = str:sub(i, i)

	  local boundary, keep = test(char)

	  if keep then
	  	part = part .. char
	  end

	  if boundary then
	    	collect()
	  end
	end

	collect()
	return parts
end

local function trim_left_impl(str, class)
	class = class or "%s+"
	return string.gsub(str, "^" .. class, "")
end

local function trim_right_impl(str, class)
	class = class or "%s+"
	return string.gsub(str, class .. "$", "")
end

local function trim_impl(str, class)
	return trim_right_impl(trim_left_impl(str, class), class)
end

local function join_impl(...)
	local parts = {...}
	for i = 1, #parts do
		parts[i] = tostring(parts[i])
	end
	return table.concat(parts)
end

local 	StringBuilder = require('eonz.objects').class "StringBuilder"
do
	function StringBuilder.new()
		return setmetatable({parts={}}, StringBuilder)
	end

	function StringBuilder:append(...)
		table.insert(self.parts, join_impl(...))
		return self
	end

	function StringBuilder:format(fmt, ...)
		return self:append(string.format(fmt, ...))
	end

	function StringBuilder:__tostring()
		return join_impl(unpack(self.parts))
	end
end

local function builder_impl()
	return StringBuilder.new()
end

local polyfills = {
	{ name = "trim_left", 		impl = trim_left_impl },
	{ name = "trim_right", 		impl = trim_right_impl },
	{ name = "trim", 		impl = trim_impl },
	{ name = "split", 		impl = split_impl },
	{ name = "join", 		impl = join_impl },
	{ name = "builder", 		impl = builder_impl },
	{ name = "StringBuilder", 	impl = StringBuilder },
}

return polyfills
