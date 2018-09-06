local eonz 		= require "eonz"
local Token 		= require "eonz.lexer.token"
local Production	= require "eonz.lexer.production"

tests["Production - general properties"] = function()

	assert_same(eonz.objects.BaseObject, getmetatable(Token))
	assert_same(eonz.objects.BaseObject, getmetatable(Production))

	local p = Production("example", "[a-z]+")

	assert_equals		("example", 		p:id())
	assert_table_equals	({"[a-z]+"},		p:patterns())
	assert_table_equals	({"^()([a-z]+)()"},	p:compile())

end

tests["Production:modes(), :channels(), :actions()"] = function()

	local p1 = Production("example", "[a-z]+")

	assert_table_equals({ 'default' }, p1:modes())
	assert_true(p1:modes('default'))
	assert_table_equals({}, p1:channels())
	assert_table_equals({}, p1:actions())
	assert_table_equals({}, p1:predicates())

	local function dummy_predicate_1() 	end
	local function dummy_predicate_2() 	end
	local function dummy_action() 		end

	local p2 = Production("example", "[a-z]+", {
		mode 		= "inside-tag",
		channels	= { "whitespace", "ignore" },
		action 		= dummy_action,
		predicates	= { dummy_predicate_1, dummy_predicate_2 }
	})

	assert_table_equals({ 'inside-tag' }, p2:modes())
	assert_false(p2:modes('default'))
	assert_true(p2:modes('inside-tag'))

	assert_table_equals({ "whitespace", "ignore" }, p2:channels())
	assert_true(p2:channels('whitespace'))
	assert_true(p2:channels('ignore'))
	assert_false(p2:channels('comments'))
	assert_table_equals({dummy_action}, p2:actions())
	assert_table_equals({ dummy_predicate_1, dummy_predicate_2 }, p2:predicates())

end

tests["Production:match()"] = function()

	local text 		= Production("TEXT", 	"[%a]+")
	local whitespace	= Production("WS",	"%s+")

	local input = "\n\thello world\n"
	local token

	assert_not(text:match(input, 1))
	token = assert(whitespace:match(input, 1))

	assert_equal("WS", 	token:id())
	assert_equal("\n\t", 	token:text())
	assert_equal(1,		token:start())
	assert_equal(3,		token:stop())
	assert_same(input,	token:source())
	assert_same(whitespace,	token:production())

	assert_not(whitespace:match(input, token:stop()))
	token = assert(text:match(input, token:stop()))

	assert_equal("TEXT", 	token:id())
	assert_equal("hello", 	token:text())
	assert_equal(3,		token:start())
	assert_equal(8,		token:stop())
	assert_same(input,	token:source())
	assert_same(text,	token:production())

	assert_not(text:match(input, token:stop()))
	token = assert(whitespace:match(input, token:stop()))

	assert_equal("WS", 	token:id())
	assert_equal(" ", 	token:text())
	assert_equal(8,		token:start())
	assert_equal(9,		token:stop())
	assert_same(input,	token:source())
	assert_same(whitespace,	token:production())

	assert_not(whitespace:match(input, token:stop()))
	token = assert(text:match(input, token:stop()))

	assert_equal("TEXT", 	token:id())
	assert_equal("world", 	token:text())
	assert_equal(9,		token:start())
	assert_equal(14,	token:stop())
	assert_same(input,	token:source())
	assert_same(text,	token:production())

	assert_not(text:match(input, token:stop()))
	token = assert(whitespace:match(input, token:stop()))

	assert_equal("WS", 	token:id())
	assert_equal("\n", 	token:text())
	assert_equal(14,	token:start())
	assert_equal(15,	token:stop())
	assert_same(input,	token:source())
	assert_same(whitespace,	token:production())

	assert_not(text:match(input, token:stop()))
	assert_not(whitespace:match(input, token:stop()))
end


tests["Production:match() with alternatives"] = function()

	local p = Production("CONSTANT", {
		"\"([^\"]*)\"",
		"([%d]+)"
	})

	local m1 = assert_exists(p:match("\"this is a string\"", 1))
	local m2 = assert_exists(p:match("2024", 1))

	assert_equal(1, m1:alternative())
	assert_equal(1, m1:alt())
	assert_equal("this is a string", m1:captures()[1])
	assert_equal(2, m2:alternative())
	assert_equal(2, m2:alt())
	assert_equal("2024", m2:captures()[1])


end
