-- NOTE: This module is a dependency of `eonz.platform` and will be loaded
-- before the cross-platform path system is initialized. It must be entirely
-- platform agnostic.

local merge_tables 	= require('eonz.polyfill.detail.merge')
local options 		= {}
local pf		= require "eonz.polyfill"
local string_split	= pf.get_extension('string', 'split')

-- options can be supplied as a table or a single string
-- if supplied as a string, it is split into flags on any
-- whitespace, comma, or semicolon.
--
-- If supplied as a table, any array elements that are strings
-- are interpreted as flags.
--
-- Flags are added back into the table as keys. If a flag starts
-- with a tilde, the value of that key is set to `false`. All other
-- flags are given values of `true`.
--
-- Any other keys are preserved.
--
-- The final options table is created by merging the defaults table
-- into a new empty table, and then merging the computed values
-- over the merged default values. The defaults table is not
-- modified.

function options.from(value, defaults)

	if type(value) == 'nil' then
		value = {}
	elseif type(value) == 'string' then
		value = string_split(value, " \r\n\t,;", {})
	elseif type(value) ~= 'table' then
		error('options should be either a table or a single string flag')
	end

	for i, flag in ipairs(value) do
		if type(flag) == 'string' then
			if flag:sub(1,1) == '~' then
				value[flag:sub(2, -1)] = false
			else
				value[flag] = true
			end
		end
	end

	return setmetatable(merge_tables({}, defaults or {}, value), options)

end

do options.__index = options
	local CHECK_TYPES = { 'string', 'number', 'boolean', 'table', 'function' }

	function options.check(opt, key)
		return opt[key] or error(string.format("missing required option: '%s'", key), 3)
	end

	for i, check_type in pairs(CHECK_TYPES) do
		local check_name = "check" .. check_type

		options[check_name] = function(opt, key)
			return (type(opt[key]) == check_type) and (opt[key])
				or error(string.format("missing required option of type %s: '%s'", check_type, key), 3)
		end
	end
end

return options
