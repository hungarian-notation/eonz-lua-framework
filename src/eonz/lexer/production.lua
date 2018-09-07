local eonz 	= require 'eonz'
local actions	= require 'eonz.lexer.actions'
local Token 	= require 'eonz.lexer.token'
local info	= require 'eonz.lexer.info'

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

		if type(id) == 'table' then
			opt.display = id[2]
			id = id[1]
		end

		id = id:trim()

		local instance = {
			_id 		= id,
			_display	= opt.display or id,
			_pattern 	= pattern,
			_modes		= opt.modes,
			_channels	= opt.channels,
			_actions	= opt.actions,
			_predicates	= opt.predicates,
			_error		= opt.error
		}

		return setmetatable(instance, Production)
	end

	function Production:display()
		return self._display
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

	function Production:try_match(source, init, pattern_index)
		return { string.match(source:text(), self:compile()[pattern_index], init) }
	end

	function Production:match(source, init, ctx)
		assert(info.Source:is_instance(source))

		for alternative = 1, #self:patterns() do
			local groups = self:try_match(source, init, alternative)

			if #groups ~= 0 and groups[1] then
				local start 		= groups[1]
				local token_text 	= groups[2]
				local stop 		= groups[#groups]
				local captures		= table.slice(groups, 3, -2)

				local token = Token {
					production 	= self,
					text 		= token_text,

					interval	= info.SourceInterval {
						start = start,
						stop = stop,
						source = source
					},

					captures 	= captures,
					alternative	= alternative,
					context		= ctx,
					error		= self._error
				}

				for i, predicate in ipairs(self:predicates()) do
					local token_response, rule_response = predicate(ctx, token)

					if rule_response == false then
						return nil
					elseif not token_response then
						token = nil
						break
					end
				end

				if token then
					return token
				end
			end
		end

		return nil
	end
end

return Production
