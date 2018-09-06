local eonz 		= require "eonz"
local Production 	= require "eonz.lexer.production"

local Context = eonz.class "eonz::lexer::Context"
do
	function Context.new(opt)
		opt = eonz.options.from(opt)

		return setmetatable({
			_gmr 	= assert(opt.grammar, 'missing grammar from arguments table'),
			_src	= assert(opt.text or opt.source_text or opt.source, 'missing source from arguments table'),
			_pos	= opt.init or 0,
			_tok	= {},
			_mod	= { opt.mode },
		}, Context)
	end

	function Context:grammar()
		return self._gmr
	end

	function Context:productions()
		return self:grammar():productions()
	end

	function Context:source()
		return self._src
	end

	function Context:token_index(i)
		if type(i) ~= 'number' then error('token index not a number', 2) end
		return (i < 0) and (#self._tok + (i + 1)) or i
	end

	function Context:tokens(i)
		if i and type(i) ~= 'number' then error('token index not a number', 2) end
		return i and self._tok[self:token_index(i)] or self._tok
	end

	function Context:remove_token(i)
		if i and type(i) ~= 'number' then error('token index not a number', 2) end
		return table.remove(self._tok, self:token_index(i or -1))
	end

	function Context:insert_token(token, i)
		if i and type(i) ~= 'number' then error('token index not a number', 2) end
		table.insert(self._tok, (i) and (self:token_index(i)) or (#self._tok + 1), token)
	end

	function Context:position(set)
		if set then
			self._pos = set
		end

		return self._pos
	end

	function Context:push_mode(mode)
		table.insert(self._mod, mode)
	end

	function Context:pop_mode()
		table.remove(self._mod)
	end

	function Context:mode(set)
		if set then
			self._mod[#self._mod] = set
		end

		return self._mod[#self._mod] or Production.DEFAULT_MODE
	end

	function Context:eof()
		return self:position() > self:source():len()
	end

	function Context:try(production)
		if not production:modes(self:mode()) then
			return nil
		else
			--print(production:id() .. " is valid in mode " .. self:mode())

			for i, predicate in ipairs(production:predicates()) do
				if not predicate(self, production) then
					return nil
				end
			end

			return production:match(self:source(), self:position())
		end
	end

	function Context:accept(token)
		local npos = #self._tok + 1

		self:insert_token(token, npos)
		self:position(token:stop())

		for i, action in ipairs(token:production():actions()) do
			action(self, token)
		end

		local lpos = #self._tok

		return table.slice(self._tok, npos, lpos)
	end

	function Context:next()
		if self:eof() then
			return nil, nil
		end

		local best = nil

		for i, production in ipairs(self:productions()) do
			local token = self:try(production)

			if token and (not best or token:len() > best:len()) then
				best = token
			end
		end

		if not best then
			return nil, self:position()
		end

		return self:accept(best)
	end

	function Context:consume()
		repeat until not self:next()
	end
end

return Context
