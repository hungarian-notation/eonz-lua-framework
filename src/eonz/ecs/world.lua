
local World = eonz.class "eonz::ecs::World"
do
	function World.new()
		return setmetatable({

			population = {},
			components = {},

		}, metatable)
	end
end
