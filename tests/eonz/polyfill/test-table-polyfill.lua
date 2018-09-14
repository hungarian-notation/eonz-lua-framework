local pf	= require 'eonz.polyfill'
local table 	= pf.extended 'table'
local string	= pf.extended 'string'

test["table.equals(a, b) arrays"] = function()

	assert_equals(true, table.equals(
		{ 'a', 'b', 'c' },
		{ 'a', 'b', "c" }
	))

	assert_equals(true, table.equals(
		{ 1, 2, 3 },
		{ 1.0, 2.0, 3.0 }
	))

	assert_equals(false, table.equals(
		{ 'a', 'b', 'c' },
		{ 'c', 'b', 'a' }
	))

	assert_equals(false, table.equals(
		{ 1, 2, 3 },
		{ 1.0, 2.0, 3.0, 4.0 }
	))
end

test["table.equals(a, b) arrays torture test"] = function()

	assert_equals(false, table.equals(
		{ 'a', 'b', 'c' },
		{}
	))

	assert_equals(false, table.equals(
		{},
		{ "a", "b", "c" }
	))

	assert_equals(false, table.equals(
		{ 'a', 'b', 'c' },
		{ 'a', 'b', 'c', ["a"] = "some-key" }
	))

end

test["table.equals(a, b, true) recursive mode"] = function()
	local a = {
		"a", "b", "c", { "d", "e" },
		x = { 1, 2, 3 },
		y = { 4, 5, 6 },
	}

	local b = {
		"a",
		y = { 4, 5, 6 },
		"b",
		x = { 1, 2, 3 },
		"c", { "d", "e" },
	}

	assert_false(table.equals(a, b))
	assert_true(table.equals(a, b, true))
end

test["table.slice()"] = function()
	local a = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 	}
	local b = { 	 4, 5, 6, 7, 8, 9, 10, 11 		}
	local c = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 	}

	assert_equals(false, a == b)
	assert_equals(false, a == c)
	assert_equals(false, table.equals(a, b))
	assert_equals(true,  table.equals(a, c))
	assert_equals(true,  table.equals(table.slice(a, 4, 11), b))
	assert_equals(true,  table.equals(table.slice(a, 4, 11), b))
	assert_equals(true,  table.equals(table.slice(c, -9, -2), b))

end

test["table.slice() graceful failure when out of bounds"] = function()
	do
		local array 	= { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
		local expected 	= { 5, 6, 7, 8, 9, 10, 11, 12 }
		local actual 	= table.slice(array, 5, 100)

		assert_table_equals(expected, actual)
	end

	do
		local array = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }
		local expected = { }
		local actual = table.slice(array, 100, 105)

		assert_table_equals(expected, actual)
	end
end

test["table.index == table.index_of"] = function()
	assert_same(table.index, table.index_of)
end

test["table.reverse()"] = function()
	local array 	= { 1, 2, 3, 4, 5 }
	local expected 	= { 5, 4, 3, 2, 1 }
	local actual  	= table.reverse(array)

	assert_table_equals(expected, actual)
end

test["table.slice() end index before start index"] = function()
	local array 	= { 1, 2, 3, 4, 5 }

	local expected_1 	= {}
	local actual_1 		= table.slice(array, 5, 1)
	local expected_2 	= { 5, 4, 3, 2, 1 }
	local actual_2 		= table.reverse(table.slice(array, 1, 5))

	assert_table_equals(expected_1, actual_1)
	assert_table_equals(expected_2, actual_2)
end

test["table.join() applies metamethod?"] = function()
	local a = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 	}
	local b = { 1, 2, 3, 4, 5, 6			}
	local c = { 		  7, 8, 9, 10, 11, 12 	}

	assert_equals(true,  table.equals(table.slice(a, 1, 6), b))
	assert_equals(true,  table.equals(table.slice(a, 7, 12), c))
	assert_equals(true,  table.equals(table.join(b, c), a))

end

test["table.is_array(arr)"] = function()
	local a = { 1, 2, "3", 4 }
	local b = { 1, 2, "3", 4 }
	local c = { 1, 2, "3", 4, key="value" }
	local d = { 1, 2, "3", 4, ["5"]="value" }
	local e = {}

	assert_equals(false,  	table.is_array(nil))
	assert_equals(false,  	table.is_array("hello"))
	assert_equals(false,  	table.is_array(1000))
	assert_equals(false,  	table.is_array(true))

	assert_equals(true, 	table.is_array(a))
	assert_equals(true, 	table.is_array(a))
	assert_equals(true,	table.is_array(b))
	assert_equals(false, 	table.is_array(c))
	assert_equals(false, 	table.is_array(d))
	assert_equals(false, 	table.is_array(d))
	assert_equals(true, 	table.is_array(e))
end

test["array table.tostring() behavior"] = function()
	local a = { 1, 2, "3", 4 }
	local a_alt = { 1, ["2"]=2, "3", 4 }
	local b = {}
	local c = { nil }

	local d = {
		"this", "is", "an",
		setmetatable({},{__tostring=function() return "\"array\"" end}),
		"of strings"
	}

	local e = { { 1, 2 }, "3", "4", { { 5 }, { 6 }}}

	assert_equals("[1, 2, \"3\", 4]",  table.tostring(a))

	assert_equals("{[1]=1, [2]=2, [3]=\"3\", [4]=4}", table.tostring(a, "~arrays"))
	assert_equals("{[1]=1, [\"2\"]=2, [2]=\"3\", [3]=4}", table.tostring(a_alt, "~arrays"))



	assert_equals("[1, 2, \"3\", 4]", table.tostring(a))
	assert_equals("[]", table.tostring(b))
	assert_equals("[]", table.tostring(c))
	assert_equals('["this", "is", "an", "array", "of strings"]',  table.tostring(d))

	assert_equals('[[1, 2], "3", "4", [[5], [6]]]',  table.tostring(e))

	assert_equals(string.trim([==[
[
  [
    1,
    2
  ],
  "3",
  "4",
  [
    [
      5
    ],
    [
      6
    ]
  ]
]
	]==]), table.tostring(e, {"pretty"}))

end

test["table.tostring() behavior"] = function()

	local a = { { 1, 2 }, "3", "4", { { 5 }, { 6 }}}
	local b = { 1, 2, 3, 4, { key = "value" }}

	assert_equals('[[1, 2], "3", "4", [[5], [6]]]', table.tostring(a))
	assert_equals('[1, 2, 3, 4, {key="value"}]', table.tostring(b))

end

test["table.merge()"] = function()
	local base 	= { 1, 2, 4, 6, 8, best_star_trek_captain = "Kirk" }
	local a 	= { [4] = "six" }
	local b 	= { best_star_trek_captain = "Quark", best_star_trek_series = "Deep Space 9" }
	local c 	= { best_star_trek_captain = "Picard", "one" }

	local result = table.merge(base, a, b, c)

	local expected = {
		"one", 2, 4, "six", 8,
		best_star_trek_captain = "Picard",
		best_star_trek_series = "Deep Space 9"
	}

	assert_table_equals(expected, result)
	assert_table_equals(expected, base)
	assert_raw_equals(result, base)
end

--[[
test["table.array, table.__eq (table as metatable)"] = function()

	local a = { 1, 2, 3, 4, 5 }
	local b = setmetatable({ 1, 2, 3, 4, 5 }, table)
	local c = { "1", "2", "3", "4", "5" }
	local d = { 1, 2, 3, 4, 5 }

	assert_equals(true, 	table.equals(a, b))
	assert_equals(true, 	table.equals(b, a))

	-- metamethod is not reliably invoked across all versions, so this
	-- must fail

	assert_equals(false, 	a == d)
	assert_equals(false, 	b == d)
	assert_equals(false, 	getmetatable(a).__eq(a, d))
	assert_equals(false, 	getmetatable(a).__eq(a, d))

	-- but the tables should still be considered "equal"

	assert_equals(true, 	table.equals(a, d))
	assert_equals(true, 	table.equals(b, d))
	assert_equals(false, 	a ~= b)
	assert_equals(false, 	b ~= a)
	assert_equals(false, 	a == c)
	assert_equals(false, 	b == c)
	assert_equals(true, 	a ~= c)
	assert_equals(true, 	b ~= c)
	assert_equals(true, 	c == c)
	assert_equals(false, 	c ~= c)
	assert_equals(false, 	a == nil)
	assert_equals(false, 	b == nil)
	assert_equals(false, 	c == nil)
end
--]]

test["table.equals(a, b) with mixed keys and array"] = function()

	local a = {
		"This", "is", "a", "mixed",
		what="table",
		why="it contains both keys and array elements"
	}

	local b = {
		why="it contains both keys and array elements",
		"This",
		what="table",
		"is", "a", "mixed"
	}

	local c = {
		why="it contains both keys and array elements",
		"This", "mixed",
		what="table",
		"is", "a"
	}

	local d = {
		"This", "is", "a", "mixed",
		what="table",
		why="it contains both keys and array elements",
		when="always"
	}

	assert_equals(true, table.equals(a, b))
	assert_equals(true, table.equals(b, a))

	assert_equals(false, table.equals(a, c))
	assert_equals(false, table.equals(c, a))
	assert_equals(false, table.equals(b, c))
	assert_equals(false, table.equals(c, b))
	assert_equals(false, table.equals(a, d))
	assert_equals(false, table.equals(d, a))
	assert_equals(false, table.equals(b, d))
	assert_equals(false, table.equals(d, b))
	assert_equals(false, table.equals(c, d))
	assert_equals(false, table.equals(d, c))
end

test["table.join(...) array join"] = function()
	local a = { 1, 2, 3, 4 }
	local b = { 5, 6 }
	local c = { 7, 8, 9 }
	local d = {}
	local e = { 10 }

	local expected = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }

	local joined 		= table.join(a, b, c,      d, e)
	local joined_inline_nil = table.join(a, b, c, nil, d, e)

	assert_equals(true, table.equals(expected, joined))
	assert_equals(true, table.equals(expected, joined_inline_nil))
end
