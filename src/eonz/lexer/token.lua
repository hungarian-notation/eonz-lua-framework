local eonz	= require 'eonz'
local table 	= eonz.pf.table
local string	= eonz.pf.string
local info = require 'eonz.lexer.info'

local Token = eonz.class "eonz::lexer::Token"
do
	Token.ERROR_TOKEN 		= 'error'
	Token.ERROR_TOKEN_UNMATCHED 	= 'unexpected token'
	Token.DEFAULT_CHANNEL		= 'default'

	function Token.new(args)
		local instance = {
			_error		= args.error and (args.production and args.production:id()) or args.error,
			_production 	= not args.error and assert(args.production) or args.production or nil,
			_interval	= assert(args.interval),
			_alternative	= not args.error and assert(args.alternative) or 1,
			_text		= args.text,
			_captures	= args.captures or {},
			_ctx		= args.context,
			_line_info	= args.line_info,
			_index		= nil,
			_data		= {}
		}

		return setmetatable(instance, Token)
	end

	function Token:merge(other)
		--if self:stop() ~= other:start() then
		--	error("non-adjacent", 2)
		--end

		return Token {
			production 	= self:production(),

			interval	= info.SourceInterval {
				start 	= self:start(),
				stop	= other:stop(),
				source	= self:source(),
			},

			captures	= table.join(self:captures(), other:captures()),
			alternative	= -1,
			context		= self:context(),
			data		= table.merge({}, self:data(), other:data())
		}
	end

	function Token:virtualize()
		return Token {
			production 	= self:production(),
			interval	= info.SourceInterval {
				start 	= self:start(),
				stop 	= self:start(),
				source	= self:source()
			},
			captures	= {},
			alternative	= -2,
			context		= self:context(),
			data		= table.copy(self:data())
		}
	end

	function Token:adjacent(count, channels)
		if not channels then
			local index = self:index() + count
			return self:context():tokens(index)
		else
			local next_index, next_token
			local origin	= self:index()
			local dir 	= count < 0 and -1 or 1
			local i 	= 0
			local j		= 0

			while j ~= count do
				i		= i + dir
				next_index 	= i + origin
				next_token	= self:context():tokens(next_index)

				if not next_token then
					break
				elseif next_token:channels(channels) then
					j = j + dir
				end
			end

			if j ~= count then
				return nil
			else
				return next_token
			end
		end
	end

	--[[--
		gets the token's absolute index in the token stream
	--]]--
	function Token:index()
		if not self._index then
			self._index = table.index_of(self:context():tokens(), self) or -1
		end

		return self._index > 0 and self._index or nil
	end

	--[[--
		get the token's channel list, or test if the token is in one
		or more channels.
	--]]--
	function Token:channels(test)
		if test then
			local own = self:channels()

			if type(test) == 'string' then
				test = { test }
			end

			for i, c in ipairs(test) do
				if table.contains(own, c) then
					return true
				end
			end

			return false
		else
			return self:production() and self:production():channels() or { Token.DEFAULT_CHANNEL }
		end
	end

	function Token:data()
		return self._data
	end

	function Token:context()
		return self._ctx
	end

	function Token:interval()
		return self._interval
	end

	function Token:source()
		return self:interval():source()
	end

	function Token:line_info()
		if self:source() and not self._line_info then
			self._line_info = self:source():line_at(self:start())
		end

		return self._line_info
	end

	function Token:line_number()
		return self:line_info() and (self:line_info():index()) or -1
	end

	function Token:line_position()
		return self:line_info() and (self:start() - self:line_info():start() + 1) or -1
	end

	function Token:error()
		return self._error
	end

	function Token:text(test)
		if not self._text then
			self._text = self:source():sub(self:start(), self:stop() - 1)
		end

		if test then
			return self._text == test
		else
			return self._text
		end
	end

	function Token:id(test)
		if self:error() then
			if type(test) ~= 'table' then
				test = {test}
			end

			--print(table.tostring(test), self:error(), Token.ERROR_TOKEN)

			return ((#test) == 0 and self:error())
				or table.contains(test, self:error())
				or table.contains(test, Token.ERROR_TOKEN)
		else
			return self:production():id(test)
		end
	end

	function Token:production()
		return self._production
	end

	function Token:captures(i, test)
		if i then
			local value = self._captures[i]

			if test then
				return value == test
			else
				return value
			end
		else
			return self._captures
		end
	end

	function Token:alternative(test)
		if test then
			return self._alternative == test
		else
			return self._alternative
		end
	end

	Token.alt = Token.alternative

	function Token:start()
		return self:interval():start()
	end

	function Token:stop()
		return self:interval():stop()
	end

	function Token:len()
		return self:stop() - self:start()
	end

	function Token:__len()
		-- not compatible across all target versions
		return self:len()
	end

	function Token:__tostring()
		--if self:error() then return "(ERROR)" end

		local sanitized = self:text()

		sanitized = sanitized:gsub("%s", "·")
		sanitized = sanitized:gsub("\\", "\\\\")
		sanitized = sanitized:gsub("\"", "\\\"")

		return "(" .. self:id() .. " \"" .. sanitized
		.. "\""
		.. (#self._captures > 0 and (" " .. table.tostring(self._captures)) or "")
		.. " " .. self:interval():start_position():tostring(true)
		.. " to " .. self:interval():stop_position():tostring(true)
		.. ")"
	end
end

return Token
