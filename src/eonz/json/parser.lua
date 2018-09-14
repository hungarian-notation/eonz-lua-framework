local eonz 		= require 'eonz'
local table 		= eonz.pf.table
local string		= eonz.pf.string

local Stream 		= require 'eonz.lexer.stream'
local Context 		= require 'eonz.lexer.context'
local GenericParser 	= require 'eonz.lexer.parser'
local grammar		= require 'eonz.json.grammar'

local Parser = eonz.class {
	name		= "eonz::json::JsonParser",
	extends		= GenericParser
}
do
	function Parser:init(opt)
		opt = eonz.options.from(opt, {
			grammar = require('eonz.json.grammar')
		})

		GenericParser.init(self, opt)
	end

	function Parser:is_relaxed()
		return self:options().relaxed
	end

	function Parser:is_tolerant()
		return self:options().tolerant
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

		if self:peek('constant') then
			return self:leave(self:constant())
		elseif not simple and self:peek('array.start') then
			return self:leave(self:array())
		elseif not simple and self:peek('object.start') then
			return self:leave(self:object())
		elseif self:peek({ 'string.start', 'string.single.start', 'error.unquoted.start' }) then
			return self:leave(self:string())
		elseif self:peek('number') then
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

		if self:is_tolerant() and self:peek('error.unquoted.start') then
			stop_rule = { 'error.unquoted.stop' }
			character_rule	= 'error.unquoted'
			self:consume('error.unquoted.start')
		elseif self:is_relaxed() and self:peek('string.single.start') then
			stop_rule 	= 'string.single.stop'
			character_rule	= 'string.single.character'
			self:consume('string.single.start')
		else
			self:expect_not('error.unquoted.start', "can not match unqoted strings outside of tolerant mode")
			self:expect_not('string.single.start', 	"can not match single-quote strings outside of relaxed mode")
			self:consume('string.start')
		end

		while not self:peek(stop_rule) do
			self:expect_not(nil, 'reached end of file while in string', {
				location = "while parsing string at " .. self.format_position(start)
			})

			if self:peek('error.string.linebreak') then
				self:syntax_error("Strings may not contain line breaks.", {
					location = "while parsing string at " .. self.format_position(start)
				})
			end

			if self:peek('string.escape') then
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

		while not self:peek('array.stop') do
			if self:is_tolerant() then
				repeat until not self:consume_optional('sep.list')
			end

			values[i] = self:value()
			i = i + 1

			self:expect_not('sep.pair', 'key-value pairs are not allowed in an array.\n\tDid you mean to use { } instead of [ ]?')

			if not self:consume_optional('sep.list') then
				break
			end

			if self:is_tolerant() then
				repeat until not self:consume_optional('sep.list')
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

		while not self:peek('object.stop') do
			if self:is_tolerant() then
				repeat until not self:consume_optional('sep.list')
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

			if not self:consume_optional('sep.list') then
				break
			end

			if self:is_tolerant() then
				repeat until not self:consume_optional('sep.list')
			end

			if not self:is_tolerant() and not self:is_relaxed() then
				self:expect_not('object.stop', 'illegal trailing comma at end of object')
			end
		end

		self:expect_not('array.stop', "found array bracket ']' where an object bracket '}' was expected.")
		self:consume('object.stop')

		return self:leave(object)
	end
	--[[
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
	--]]
end

return Parser
