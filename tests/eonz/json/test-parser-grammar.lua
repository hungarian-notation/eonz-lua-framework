local eonz 		= require "eonz"

local Token 		= require "eonz.lexer.token"
local Grammar		= require "eonz.lexer.grammar"
local Context		= require "eonz.lexer.context"

local json 		= require "eonz.json"
local mock_input	= require "eonz.json.validation-set" -- from testlib

tests['parser validation suite'] = function()
	assert_same(Grammar, getmetatable(json.grammar))

	local function invoke(context, fn, ...)
		local function host(...)
			return fn(...)
		end

		local results = { pcall(host, ...) }
		if results[1] then
			return table.unpack(table.slice(results, 2))
		else
			fail(context .. ": " .. tostring(results[2]))
		end
	end

	for i, mock in ipairs(mock_input) do
		local parser = json.parser({ source = mock[1], tolerant = false, relaxed = false })


		for i, token in ipairs(parser:stream():list()) do
			print(token)
		end

		local result = invoke("in parser:json() for mock #" .. tostring(i) , parser.json, parser)


		if type(result) == 'table' then
			assert_deep_equals(mock[2], result,  "parser:json() returned wrong value for mock #" .. tostring(i) .. ".")
		else
			assert_equals(mock[2], result, "parser:json() returned wrong value for mock #" .. tostring(i) .. ".")
		end
	end
end
