local eonz 		= require "eonz"
local Token 		= require "eonz.lexer.token"
local Production	= require "eonz.lexer.production"
local Grammar		= require "eonz.lexer.grammar"
local Context		= require "eonz.lexer.context"
local actions		= require "eonz.lexer.actions"

tests["Production:match()"] = function()

	local grammar = Grammar {

		-- Grammar's constructor will attempt to unpack any arguments
		-- in the production list that are not instances of
		-- `Production` as arguments to the Production constructor.
		--
		-- This is done argument-by-argument, so a mixed list is
		-- acceptable.

		Production
		(
			"TEXT",
			"[^%s<]+"
		),

		{
			"WS",
			"%s+"
		},
		{
			"TAG_ENTER",
			"<%s*(/?)%s*([%a%d%-]+)",
			{
				push_mode = "in-tag"

				-- shortcut for:
				-- actions = { eonz.lexer.actions.push_mode("in-tag") }
			}
		},
		{
			"TAG_CONTENT",
			{
				"[^/>]+",
				"[/]"
			},

			-- In table form, the production option keys can be
			-- specified in the base table.

			mode 	= "in-tag",
			action	= actions.merge_alike()
		},
		{
			"TAG_EXIT",
			"(/?)%s*>",

			-- this mode option will be overridden, as options
			-- defined in the options table take precedence over
			-- those defined in the base table

			mode = "never",

			{
				-- this mode option is the one that will be
				-- used

				mode 	= "in-tag",
				action	= actions.pop_mode()
			}
		},
	}

	local source = "<a href='./message.htm'>Hello, World!<br/>< /a >"

	local context = Context {
		grammar = grammar,
		source	= source
	}

	context:consume()

	local tokens = context:tokens()

	--print(table.tostring(tokens, 'pretty'))

	--[[
		Expected Output:

		(TAG_ENTER "<a" ["", "a"])
		(TAG_CONTENT "·href='./message.htm'")
		(TAG_EXIT ">" [""])
		(TEXT "Hello,")
		(WS "·")
		(TEXT "World!")
		(TAG_ENTER "<br" ["", "br"])
		(TAG_EXIT "/>" ["/"])
		(TAG_ENTER "<·/a" ["/", "a"])
		(TAG_EXIT "·>" [""])
	--]]

	assert_equal(10, #tokens)
	assert_equal("TAG_ENTER", 		tokens[1]:id())
	assert_equal("<a",			tokens[1]:text())

	assert_equal("TAG_CONTENT", 		tokens[2]:id())
	assert_equal(" href='./message.htm'",	tokens[2]:text())

	assert_equal("TAG_EXIT",		tokens[3]:id())
	assert_equal(">",			tokens[3]:text())

	assert_equal("TEXT", 			tokens[4]:id())
	assert_equal("Hello,",			tokens[4]:text())

	assert_equal("WS", 			tokens[5]:id())
	assert_equal(" ",			tokens[5]:text())

	assert_equal("TEXT",			tokens[6]:id())
	assert_equal("World!",			tokens[6]:text())

	assert_equal("TAG_ENTER", 		tokens[7]:id())
	assert_equal("<br",			tokens[7]:text())

	assert_equal("TAG_EXIT", 		tokens[8]:id())
	assert_equal("/>",			tokens[8]:text())

	assert_equal("TAG_ENTER", 		tokens[9]:id())
	assert_equal("< /a",			tokens[9]:text())

	assert_equal("TAG_EXIT", 		tokens[10]:id())
	assert_equal(" >",			tokens[10]:text())
end
