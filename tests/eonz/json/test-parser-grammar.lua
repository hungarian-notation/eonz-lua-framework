local eonz 		= require "eonz"
local table 		= eonz.pf.table
local string		= eonz.pf.string

local Token 		= require "eonz.lexer.token"
local Grammar		= require "eonz.lexer.grammar"
local Context		= require "eonz.lexer.context"
local info		= require "eonz.lexer.info"


local json 		= require "eonz.json"
local mock_input	= require "eonz.json.validation-set" -- from testlib


tests['tolerant mode distinction'] = function()

	local source = info.Source {
		text = [[

			{ 'key1' : "value 1", key2 : "value 2" }

		]],
		name = 'flawed-input',
		lang = 'json'
	}

	local strict_parser 	= json.parser {
		source = source,
		tolerant = false
	}

	local relaxed_parser	= json.parser {
		source = source,
		relaxed = true
	}

	local tolerant_parser	= json.parser {
		source = source,
		tolerant = true
	}

	local relaxed_tolerant_parser	= json.parser {
		source = source,
		tolerant = true,
		relaxed = true
	}

	assert_error {
		{ contains = "can not match single-quote strings outside of relaxed mode" },
		{strict_parser}, strict_parser.json
	}

	assert_error {
		{ contains = "can not match single-quote strings outside of relaxed mode" },
		{tolerant_parser}, tolerant_parser.json
	}

	assert_error {
		{ contains = "can not match unqoted strings outside of tolerant mode" },
		{relaxed_parser}, relaxed_parser.json
	}

	assert_deep_equals({key1="value 1", key2="value 2"}, relaxed_tolerant_parser:json())

end

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
			fail(context .. ":\n\t" .. tostring(results[2]))
		end
	end

	for i, mock in ipairs(mock_input) do
		local parser = json.parser({
			source = info.Source {
				text = assert(type(mock[1]) == 'string' and mock[1]),
				name = 'mock[' .. tostring(i) .. ']',
				lang = 'json'
			},
			tolerant = false,
			relaxed = false })


		for i, token in ipairs(parser:stream():list()) do
			--print(token)
		end

		local result = invoke("in parser:json() for mock #" .. tostring(i) , parser.json, parser)


		if type(result) == 'table' then
			assert_deep_equals(mock[2], result,  "parser:json() returned wrong value for mock #" .. tostring(i) .. ".")
		else
			assert_equals(mock[2], result, "parser:json() returned wrong value for mock #" .. tostring(i) .. ".")
		end
	end
end
