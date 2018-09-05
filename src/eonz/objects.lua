local objects = {}

local BaseObject = {}
do
	function BaseObject.__call(T, ...)
		return T.new(...)
	end
end

objects.BaseObject = BaseObject

function objects.class(name)
	if type(name) == 'table' then

	elseif type(name) == 'string' then
		local table = {}
		table.__index 		= table
		table.__class_name 	= name
		return setmetatable(table, metatable)
	end
end

return objects
