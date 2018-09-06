local eonz = require "eonz"

local Token = eonz.class "eonz::lexer::Token"
do
	function Token.new(args)
		local instance = {
			_production 	= assert(args.production),
			_start		= assert(args.start),
			_stop		= assert(args.stop),
			_source		= assert(args.source),
			_alternative	= assert(args.alternative),
			_text		= args.text,
			_captures	= args.captures or {}
		}

		return setmetatable(instance, Token)
	end

	function Token:merge(other)
		if self:stop() ~= other:start() then
			error("non-adjacent", 2)
		end

		return Token {
			production 	= self:production(),
			start		= self:start(),
			stop		= other:stop(),
			source		= self:source(),
			captures	= table.join(self:captures(), other:captures()),
			alternative	= -1,
		}
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

	function Token:id(...)
		return self:production():id(...)
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
		return self._start
	end

	function Token:stop()
		return self._stop
	end

	function Token:len()
		return self:stop() - self:start()
	end

	function Token:__len()
		-- not compatible across all target versions
		return self:len()
	end

	function Token:__tostring()
		local sanitized = self:text()

		sanitized = sanitized:gsub("%s", "·")
		sanitized = sanitized:gsub("\\", "\\\\")
		sanitized = sanitized:gsub("\"", "\\\"")

		return "(" .. self:id() .. " \"" .. sanitized
		.. "\""
		.. (#self._captures > 0 and (" " .. table.tostring(self._captures)) or "")
		.. ")"
	end

	function Token:source()
		return self._source
	end
end

return Token
