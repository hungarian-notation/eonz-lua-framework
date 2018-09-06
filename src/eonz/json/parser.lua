local eonz 	= require "eonz"

local Stream 	= require "eonz.lexer.stream"
local Context 	= require "eonz.lexer.context"
local grammar	= require "eonz.json.grammar"

local Parser = eonz.class "eonz::json::Parser"
do
	function Parser.new(json, opt)
		opt = eonz.options.from(opt)
		return setmetatable({
			_json 	= json,
			_ctx	= Context { grammar = grammar, source = json },
			_stream	= nil,
			_stack 	= {},
			_opt	= opt
		}, Parser)
	end

	function Parser:options()
		return self._opt
	end

	function Parser:is_relaxed()
		return self:options().relaxed
	end

	function Parser:is_tolerant()
		return self:options().tolerant
	end

	function Parser:context()
		return self._ctx
	end

	function Parser:stream()
		if not self._stream then
			self._ctx:consume()
			self._stream = Stream(self._ctx:tokens())
		end
		return self._stream
	end

	function Parser:eof()
		return self:stream():eof()
	end



	function Parser:sees(id)
		if self:eof() then
			return id == nil
		elseif id == nil then
			return false
		end

		return self:syntax_assert(self:syntax_assert(self, 'self was nil'):look(), "self:look() returned nil"):id(id)
	end

	function Parser:look(i)
		return self:syntax_assert(self:syntax_assert(self, 'self was nil'):stream(), 'self:stream() returned nil'):look(i)
	end

	function Parser:format_ids(ids, spell_out)
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

	function Parser:consume(id)
		self:expect(id)
		self:event('consuming ', id)
		return self:syntax_assert(self:try_consume(id))
	end

	function Parser:try_consume(id)
		if id == nil or self:sees(id) then
			return self:stream():consume()
		else
			return nil
		end
	end

	function Parser:expect(ids, message, opt)
		opt = eonz.options.from(opt)
		if not self:sees(ids) then
			if not message and not ids then
				message = "expected end of file"
			end
			self:syntax_error(message or ('expected '
				.. ((type(ids) == 'table' and #ids > 1) and 'one of: ' or '')
				.. self:format_ids(ids)
				.. ' at this position'), opt)
		end
	end

	function Parser:expect_not(ids, message, opt)
		opt = eonz.options.from(opt)
		if self:sees(ids) then
			self:syntax_error(message or ('did not expect '
				.. self:format_ids(self:look() and self:look():id())
				.. ' at this position'), opt)
		end
	end

	function Parser:error_after()
		self._error_after = true
	end

	local function format_position(token)
		return string.format("%s:%s",
		token:line_number(),
		token:line_position())
	end

	function Parser:syntax_error(message, opt)
		opt = eonz.options.from(opt)

		local bf = string.builder()
		local rule = self._stack[#self._stack]
		local next_token = self:look(1)
		local last_token = self:look(-1)

		local function write_token(offset)
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
				bf:format("while parsing JSON %s: ", rule)
			end
		end

		if not opt.location and not opt.skip_position then
			if self:eof() then
				bf:append("at end of file: ")
			elseif next_token and ((not last_token) or (not opt.after)) then
				bf:format("at %s at %d:%d:",
					write_token(1),
					next_token:line_number(),
					next_token:line_position(),
					self:format_ids(1))
			elseif last_token then
				bf:format("after %s at %d:%d: ",
					write_token(-1),
					last_token:line_number(),
					last_token:line_position())
			end
		end

		bf:append("\n\t")
		bf:append(message)

		eonz.error(tostring(bf))
	end

	function Parser:syntax_assert(test, ...)
		if not test then
			self:syntax_error(...)
		else
			return test
		end
	end

	function Parser:json()
		self:enter_rule "json"
		local value = self:leave(self:value())
		self:expect(nil)
		return value
	end

	local VALUE_EXPECT_MESSAGE = 'expected a value here (boolean, number, string, object, or array)'

	function Parser:value(simple)
		self:enter_rule "value"

		if self:sees('constant') then
			return self:leave(self:constant())
		elseif not simple and self:sees('array.start') then
			return self:leave(self:array())
		elseif not simple and self:sees('object.start') then
			return self:leave(self:object())
		elseif self:sees({ 'string.start', 'string.single.start', 'error.unquoted.start' }) then
			return self:leave(self:string())
		elseif self:sees('number') then
			return self:leave(self:number())
		else
			self:syntax_error(VALUE_EXPECT_MESSAGE)
		end
	end

	function Parser:constant()
		self:enter_rule "constant"
		return self:leave(({
			true,
			false,
			nil
		})[self:consume('constant'):alt()])
	end

	function Parser:number()
		self:enter_rule "number"
		return self:leave(tonumber(self:consume('number'):text()))
	end

	local EXPLICIT_ESCAPES = {
		a = '\a', -- EXTENSION - \a is not in JSON standard
		v = '\v', -- EXTENSION - \v is not in JSON standard
		b = '\b',
		f = '\f',
		n = '\n',
		r = '\r',
		t = '\t'
	}

	function Parser:lookup_escape(char)
		self:event('processing escape: ', char)
		return EXPLICIT_ESCAPES[char] or char
	end

	function Parser:string()
		self:enter_rule "string"

		local bf = string.builder()

		local start = self:look()

		-- in tolerant mode,

		local stop_rule 	= 'string.stop'
		local character_rule	= 'string.character'

		if self:is_tolerant() and self:sees('error.unquoted.start') then
			stop_rule = { 'error.unquoted.stop' }
			character_rule	= 'error.unquoted'
			self:consume('error.unquoted.start')
		elseif self:is_relaxed() and self:sees('string.single.start') then
			stop_rule 	= 'string.single.stop'
			character_rule	= 'string.single.character'
			self:consume('string.single.start')
		else
			self:expect_not('error.unquoted.start', 	"can not match unqoted keys outside of tolerant mode")
			self:expect_not('string.single.start', 	"can not match single-quote strings outside of relaxed mode")
			self:consume('string.start')
		end

		while not self:sees(stop_rule) do

			self:expect_not(nil, 'reached end of file while in string', {
				location = "while parsing string at " .. format_position(start)
			})

			if self:sees('error.string.linebreak') then
				self:syntax_error("Strings may not contain line breaks.", {
					location = "while parsing string at " .. format_position(start)
				})
			end

			if self:sees('string.escape') then
				local escape = self:consume('string.escape')

				if escape:alt(1) then
					bf:append(self:lookup_escape(escape:captures(1)))
				else
					bf:append(string.char(tonumber(escape:captures(1), 16)))
				end
			else
				bf:append(self:consume(character_rule):text())
			end
		end

		self:consume(stop_rule)

		return self:leave(tostring(bf))
	end

	function Parser:array()
		self:enter_rule "array"
		self:consume('array.start')

		local values = {}
		local i = 1

		while not self:sees('array.stop') do
			if self:is_tolerant() then
				repeat until not self:try_consume('sep.list')
			end

			values[i] = self:value()
			i = i + 1

			self:expect_not('sep.pair', 'key-value pairs are not allowed in an array.\n\tDid you mean to use { } instead of [ ]?')

			if not self:try_consume('sep.list') then
				break
			end

			if self:is_tolerant() then
				repeat until not self:try_consume('sep.list')
			end

			if not self:is_tolerant() and not self:is_relaxed() then
				self:expect_not('array.stop', 'illegal trailing comma at end of array')
			end
		end

		self:expect_not('object.stop', "found object bracket '}' where an array bracket ']' was expected.")
		self:consume('array.stop')
		return self:leave(values)
	end

	function Parser:object()
		self:enter_rule "object"
		self:consume('object.start')

		local object = {}

		while not self:sees('object.stop') do

			if self:is_tolerant() then
				repeat until not self:try_consume('sep.list')
			end

			self:expect_not(nil)

			if not self:is_relaxed() then
				self:expect_not('number', 'Expected a string property name. Unquoted number literal is not a valid JSON key. Try: \"'
					.. self:look(1):text() .. '\"')
				self:expect_not('constant', 'Expected a string property name. Unquoted constant keyword is not a valid JSON key. Try: \"'
					.. self:look(1):text() .. '\"')
				self:expect({ 'string.start', 'string.single.start', 'error.unquoted.start' }, 'expected a key-value pair', { after=false })
			end

			local key = self:is_relaxed() and self:value(true) or self:string()

			self:expect_not	('sep.list', 	"property value required here")
			self:expect	('sep.pair', 	"expected ':' token followed by property value")
			self:consume	('sep.pair')
			self:expect_not	('sep.list', 	"missing property value after ':' token")

			local value = self: value()

			object[key] = value

			if not self:try_consume('sep.list') then
				break
			end

			if self:is_tolerant() then
				repeat until not self:try_consume('sep.list')
			end

			if not self:is_tolerant() and not self:is_relaxed() then
				self:expect_not('object.stop', 'illegal trailing comma at end of object')
			end

		end

		self:expect_not('array.stop', "found array bracket ']' where an object bracket '}' was expected.")
		self:consume('object.stop')

		return self:leave(object)
	end




	function Parser:log(...)
		--io.write(string.join(...))
	end

	function Parser:transition(...)
		self:log(string.rep("|       ", #self._stack))
		self:log(string.join(...))
		self:log("\n")
	end

	function Parser:event(...)
		self:log(string.rep("|       ", #self._stack))
		self:log(#({...}) > 0 and "  - " or "")
		self:log(string.join(...))
		self:log("\n")
	end

	function Parser:enter_rule(name)
		if #self._stack == 0 then
			self:event()
		end

		self:transition('in rule: ', name)
		table.insert(self._stack, name)
	end

	function Parser:leave(...)
		local leaving = table.remove(self._stack)
		self:transition('leaving rule: ', leaving, ' (rtype:', type(({...})[1]), ')')
		return ...
	end

end

return Parser
