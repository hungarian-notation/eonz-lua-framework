
local World = eonz.class "ecs.World"
do
	function World.new()
		return setmetatable({

			population = {},
			components = {},

		}, metatable)
	end
end
