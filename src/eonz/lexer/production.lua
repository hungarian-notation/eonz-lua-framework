local eonz 	= require "eonz"
local actions	= require "eonz.lexer.actions"
local Token 	= require "eonz.lexer.token"

local Production = eonz.class "eonz::lexer::Production"
do
	Production.DEFAULT_MODE = "default"

	function Production.new(id, pattern, opt)
		opt = eonz.options.from(opt, {
			modes		= {},
			channels	= {},
			predicates	= {},
			actions		= {},
		})

		if type(opt.mode) == 'string' then
			table.insert(opt.modes, opt.mode)
		end

		if #opt.modes == 0 then
			table.insert(opt.modes, Production.DEFAULT_MODE)
		end

		if type(opt.channel) == 'string' then
			table.insert(opt.channels, opt.channel)
		end

		if type(opt.predicate) == 'function' then
			table.insert(opt.predicates, opt.predicate)
		end

		if type(opt.action) == 'function' then
			table.insert(opt.actions, opt.action)
		end

		for name, action in pairs(actions) do
			if opt[name] then
				table.insert(opt.actions, action(opt[name]))
			end
		end

		if type(pattern) == 'string' then
			pattern = { pattern }
		end

		local instance = {
			_id 		= id:trim(),
			_pattern 	= pattern,
			_modes		= opt.modes,
			_channels	= opt.channels,
			_actions	= opt.actions,
			_predicates	= opt.predicates,
		}

		return setmetatable(instance, Production)
	end

	function Production:id(test)
		if type(test) == 'string' then
			return self._id == test
		elseif type(test) == 'table' then
			return table.contains(test, self._id)
		else
			return self._id
		end
	end

	function Production:patterns()
		return self._pattern
	end

	function Production:compile()
		if not self._compiled then
			self._compiled = {}

			for i, pattern in ipairs(self:patterns()) do
				table.insert(self._compiled, "^()(" .. pattern .. ")()")
			end
		end
		return self._compiled
	end

	function Production:modes(test)
		if test then
			return table.contains(self._modes, test)
		else
			return self._modes
		end
	end

	function Production:channels(test)
		if test then
			return table.contains(self._channels, test)
		else
			return self._channels
		end
	end

	function Production:actions()
		return self._actions
	end

	function Production:predicates()
		return self._predicates
	end

	function Production:try_match(source_text, init, pattern_index)
		return { string.match(source_text, self:compile()[pattern_index], init) }
	end

	function Production:match(source_text, init)
		for alternative = 1, #self:patterns() do
			local groups = self:try_match(source_text, init, alternative)

			if #groups ~= 0 and groups[1] then
				local start 		= groups[1]
				local token_text 	= groups[2]
				local stop 		= groups[#groups]
				local captures		= table.slice(groups, 3, -2)

				return Token {
					production 	= self,
					text 		= token_text,
					start 		= start,
					stop 		= stop,
					source 		= source_text,
					captures 	= captures,
					alternative	= alternative
				}
			end
		end

		return nil
	end
end

return Production
