require('eonz.polyfill')()

local Platform = {}

require('eonz.platform.paths')(Platform)
require('eonz.platform.detect')(Platform)
require('eonz.platform.search_path')(Platform)

-- Platform will serve as the metatable for the returned value.
Platform.__index = Platform

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

return Platform
