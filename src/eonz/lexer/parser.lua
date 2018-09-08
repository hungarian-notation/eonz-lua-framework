local eonz 	= require 'eonz'
local Stream 	= require 'eonz.lexer.stream'
local Context 	= require 'eonz.lexer.context'

local GenericParser = eonz.class "eonz::lexer::GenericParser"
do
	function GenericParser:init(opt)
		opt = eonz.options.from(opt)
		self._ctx	= opt.context or Context { 	grammar = opt.grammar,
								source 	= opt.source,
								text	= opt.text 	}
		self._stream	= nil
		self._stack 	= {}
		self._trail	= {}
		self._opt	= opt
		self._error	= nil
	end

	function GenericParser:options(name)
		if name then
			return self._opt[name]
		else
			return self._opt
		end
	end

	function GenericParser:context()
		return self._ctx
	end

	function GenericParser:stream()
		if not self._stream then
			self._ctx:consume()
			self._stream = Stream(self._ctx:tokens())
		end
		return self._stream
	end

	function GenericParser:eof()
		return self:stream():eof()
	end

	function GenericParser:peek(id, offset)
		if self:eof() then
			return id == nil
		elseif id == nil then
			return false
		end

		return self:syntax_assert(self:syntax_assert(self, 'self was nil'):look(offset), "looking past end of file"):id(id)
	end

	function GenericParser:look(i)
		return self:syntax_assert(self:syntax_assert(self, 'self was nil'):stream(), 'self:stream() returned nil'):look(i)
	end

	function GenericParser:format_ids(ids, spell_out) -- WARNING: unstable api
		local token_offset

		if type(ids) == 'number' then
			token_offset = ids
			ids = nil
		end

		if token_offset then
			local token = self:look(token_offset)
			ids = { token:error() and (token:production() and token:production():display() or "error token") or token:id() }
		elseif not ids then
			return 'end of file'
		end

		if type(ids) ~= 'table' then
			ids = { ids }
		end

		local bf = string.builder()

		for i = 1, #ids do
			if i ~= 1 then
				bf:append(", ")
			end

			local display = self:context():display_for(ids[i])

			if spell_out then
				bf:format("%s token", display)
			elseif token_offset then
				bf:format("%s", self:look(token_offset):text())
			else
				bf:format("%s", display)
			end
		end

		return tostring(bf)
	end

	function GenericParser:consume(id)
		if not id then id = self:look(1):id() end
		self:expect(id)
		self:event('consuming ', self:look(1):id())
		return self:syntax_assert(self:consume_optional(id))
	end

	function GenericParser:consume_optional(id)
		if id == nil or self:peek(id) then
			return self:stream():consume()
		else
			return nil
		end
	end

	function GenericParser:expect(ids, message, opt)
		opt = eonz.options.from(opt, {
			error_type 	= 'error.syntax.expectation',
			error_expected	= ids,
			error_position	= self:stream():index()
		})

		if not self:peek(ids) then
			if not message and not ids then
				message = "expected end of file"
			end

			self:syntax_error(message or ('expected '
				.. ((type(ids) == 'table' and #ids > 1) and 'one of: ' or '')
				.. self:format_ids(ids)
				.. ' at this position'), opt)
		end
	end

	function GenericParser:expect_not(ids, message, opt)
		opt = eonz.options.from(opt)
		if self:peek(ids) then
			self:syntax_error(message or ('did not expect '
				.. self:format_ids(self:look() and self:look():id())
				.. ' at this position'), opt)
		end
	end

	function GenericParser.format_position(token)
		return string.format("%s:%s",
		token:line_number(),
		token:line_position())
	end

	function GenericParser:error()
		return self._error
	end

	function GenericParser:throw_error(message, error_info)
		self._error = error_info
		eonz.error(message)
	end

	function GenericParser:syntax_error(message, opt)
		opt = eonz.options.from(opt)

		local bf = string.builder()
		local rule = self._stack[#self._stack]
		local next_token = self:look(1)
		local last_token = self:look(-1)

		local function write_token(offset)
			-- TODO this and format_ids should be reworked

			local token = self:look(offset)

			if not token:error() and token:production():display() == token:id() then
				return string.format("%s (%s)",
					self:format_ids(offset, true),
					self:format_ids(offset))
			elseif token:error() and token:production() then
				return token:production():display()
			elseif token:error() then
				return "error token"
			else
				return self:format_ids(offset, true)
			end

		end

		if opt.location then
			bf:format("%s:", opt.location)
		elseif not opt.skip_location then
			if rule then
				bf:format("while parsing %s: ", tostring(rule))
			end
		end

		if not opt.location and not opt.skip_position then
			if self:eof() then
				bf:append("at end of file: ")
			elseif next_token and ((not last_token) or (not opt.after)) then
				bf:format("at %s at %s:",
					write_token(1),
					tostring(next_token:interval():start_position()),
					self:format_ids(1))
			elseif last_token then
				bf:format("after %s at %s: ",
					write_token(-1),
					tostring(last_token:interval():stop_position()))
			end
		end

		bf:append("\n\t")
		bf:append(message)

		self:throw_error(tostring(bf), {
			message 	= tostring(bf),
			type 		= opt.error_type or "error.syntax.general",
			position 	= self:stream():index()
		})
	end

	function GenericParser:syntax_assert(test, ...)
		if not test then
			self:syntax_error(...)
		else
			return test
		end
	end

	function GenericParser:log(...)
		if self:options('logging') == true then
			io.write(string.join(...))
		elseif self:options('logging') then
			self:options('logging')(...)
		end
	end

	function GenericParser:transition(...)
		self:log(string.rep("|       ", #self._stack))
		self:log(string.join(...))
		self:log("\n")
	end

	function GenericParser:event(...)
		self:log(string.rep("|       ", #self._stack))
		self:log(#({...}) > 0 and "  - " or "")
		self:log(string.join(...))
		self:log("\n")
	end

	function GenericParser:alternative(...)
		self:event('considering alternative: ', ...)
		self._stack[#self._stack].alternative = string.join(...)
	end

	function GenericParser:enter_rule(name)
		if #self._stack == 0 then
			self:event()
		end

		self:transition('in rule: ', name)
		table.insert(self._stack, { name=name, alternative=nil })
		self._trail = {}
	end

	function GenericParser:leave(...)
		local leaving = table.remove(self._stack)
		self:transition('leaving rule: ', leaving, ' (rtype:', type(({...})[1]), ')')
		table.insert(self._trail, leaving)
		return ...
	end

	function GenericParser:stack(i)
		return not i and self._stack or self._stack[#self._stack + 1 - i]
	end

	function GenericParser:trail(i)
		return not i and self._trail or self._trail[#self._trail + 1 - i]
	end
end

return GenericParser
