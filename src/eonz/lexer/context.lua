local eonz 		= require 'eonz'
local table 		= eonz.pf.table
local string		= eonz.pf.string

local Production 	= require 'eonz.lexer.production'
local Token 		= require 'eonz.lexer.token'
local info		= require 'eonz.lexer.info'
local Stream		= require 'eonz.lexer.stream'

local Context = eonz.class "eonz::lexer::Context"
do
	function Context.new(opt)
		opt = eonz.options.from(opt)

		if type(opt.source) == 'string' then
			opt.text = opt.source
			opt.source = nil
		end

		if not opt.source then
			opt.source = info.Source {
				text = opt:checkstring('text'),
				name = opt.name or "unknown-source",
				lang = opt.lang
			}
		end

		assert(info.Source:is_instance(opt.source), 'source option must be an instance of eonz::info::Source')

		return setmetatable({
			_gmr 	= assert(opt.grammar, 'missing grammar from arguments table'),
			_src	= opt.source,

			_pos	= opt.init or 0,
			_tok	= {},
			_mod	= { opt.mode },
			_lines	= nil
		}, Context)
	end

	function Context:production_for(id)
		return self:grammar():production_for(id)
	end

	function Context:display_for(id)
		local production = self:production_for(id)
		return production and production:display() or id
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

		if i < 0 then
			return #self._tok + i + 1
		else
			return i
		end
	end

	function Context:tokens(i)
		if i and type(i) ~= 'number' then error('token index not a number', 2) end

		if not i then
			return self._tok
		else
			return self._tok[self:token_index(i)]
		end
	end

	function Context:stream(channels)
		self:consume()

		local matched = {}

		for i, tok in ipairs(self:tokens()) do
			if tok:channels(channels) then
				table.insert(matched, tok)
			end
		end

		return Stream(matched, 1)
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

			--[[
			for i, predicate in ipairs(production:predicates()) do
				if not predicate(self, production) then
					return nil
				end
			end
			--]]

			return production:match(self:source(), self:position(), self)
		end
	end

	function Context:accept(token)
		local npos = #self._tok + 1

		self:insert_token(token, npos)
		self:position(token:stop())

		if token:production() then
			for i, action in ipairs(token:production():actions()) do
				action(self, token)
			end
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

			local valid = token and ((not best) or (not token:error()) or (best:error()))

			if valid and ((not best) or (not best or token:len() > best:len())) then
				best = token
			end
		end

		if not best then
			return self:accept(Token {
				error		= Token.ERROR_TOKEN_UNMATCHED,
				interval	= info.SourceInterval {
					start 		= self:position(),
					stop 		= self:position() + 1,
					source 		= self:source(),
				},
				context		= self
			})
		end

		return self:accept(best)
	end

	function Context:consume()
		repeat until not self:next()
	end
end

return Context
