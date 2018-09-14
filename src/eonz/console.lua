local pf 	= require 'eonz.polyfill'

local console 	= {}

--[[
	The function stubs here are available on all platforms, but may
	produce empty output if there is no appropriate implementation
	for the platform.

	On linux, the eonz.ansi module is merged on top of this module.
--]]

function console.move_cursor(x, y)
	return ""
end

function console.color()
	return ""
end

function console.reset()
	return ""
end

function console.apply()
	return ""
end

function console.style(style, ...)
	return pf.string.join(...)
end

pf.table.merge(console, require('eonz.ansi'))

return console
