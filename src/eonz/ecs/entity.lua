local eonz = require "eonz"

local Entity = eonz.class "ecs.Entity"
do
	function Entity.new(world, id)
		return setmetatable({

			world 	= world,
			id 	= id

		}, metatable)
	end
end
