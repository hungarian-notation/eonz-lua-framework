local eonz = require 'eonz'

local info = require 'eonz.lexer.info'

local Token = eonz.class "eonz::lexer::Token"
do
	Token.ERROR_TOKEN 		= 'error'
	Token.ERROR_TOKEN_UNMATCHED 	= 'unexpected token'

	function Token.new(args)
		local instance = {
			_error		= args.error and (args.production and args.production:id()) or args.error,
			_production 	= not args.error and assert(args.production) or args.production or nil,
			_interval	= assert(args.interval),
			_alternative	= not args.error and assert(args.alternative) or 1,
			_text		= args.text,
			_captures	= args.captures or {},
			_ctx		= args.context,
			_line_info	= args.line_info
		}

		return setmetatable(instance, Token)
	end

	function Token:merge(other)
		if self:stop() ~= other:start() then
			error("non-adjacent", 2)
		end

		return Token {
			production 	= self:production(),

			interval	= info.SourceInterval {
				start 	= self:start(),
				stop	= other:stop(),
				source	= self:source()
			},

			captures	= table.join(self:captures(), other:captures()),
			alternative	= -1,
			context		= self:context()
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
			context		= self:context()
		}
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
		return self:line_info() and (self:line_info().index) or -1
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
