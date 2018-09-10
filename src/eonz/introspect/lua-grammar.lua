local eonz	= require 'eonz'
local actions	= require 'eonz.lexer.actions'

local Grammar	= require 'eonz.lexer.grammar'

local FRAG_IDENTIFIER 		= "[a-zA-Z_]" .. "[a-zA-Z0-9_]*"

local FRAG_DIGIT		= "[0-9]"
local FRAG_HEX_DIGIT		= "[0-9a-fA-F]"
local FRAG_SIGN			= "[+-]"
local FRAG_OPTSIGN		= FRAG_SIGN .. "?"
local FRAG_DIGITS		= FRAG_DIGIT .. "+"
local FRAG_HEX_DIGITS		= FRAG_HEX_DIGIT .. "+"
local FRAG_POINT		= "[%.]"
local FRAG_HEX_LEADER		= "0[xX]"
local FRAG_EXP			= "[eE]" .. FRAG_OPTSIGN .. FRAG_DIGITS
local FRAG_HEX_EXP		= "[pP]" .. FRAG_OPTSIGN .. FRAG_HEX_DIGITS

local ALT_INTEGER		= FRAG_DIGITS
local ALT_INTEGER_EXP		= ALT_INTEGER .. FRAG_EXP
local ALT_HEX_INTEGER		= FRAG_HEX_LEADER .. FRAG_HEX_DIGITS
local ALT_HEX_INTEGER_EXP	= ALT_HEX_INTEGER .. FRAG_HEX_EXP
local ALT_FLOAT			= FRAG_DIGITS .. FRAG_POINT .. FRAG_DIGITS
local ALT_FLOAT_EXP		= ALT_FLOAT .. FRAG_EXP
local ALT_HEX_FLOAT		= FRAG_HEX_LEADER .. FRAG_HEX_DIGITS .. FRAG_POINT .. FRAG_HEX_DIGITS
local ALT_HEX_FLOAT_EXP		= ALT_HEX_FLOAT .. FRAG_HEX_EXP

local ALTS_NUMBER		= {
	ALT_HEX_FLOAT_EXP,
	ALT_HEX_FLOAT,
	ALT_HEX_INTEGER_EXP,
	ALT_HEX_INTEGER,
	ALT_FLOAT_EXP,
	ALT_FLOAT,
	ALT_INTEGER_EXP,
	ALT_INTEGER
}

local FRAG_COMMENT		= "%-%-"

local FRAG_LEFT_BRACKET 	= "%[(%=*)%[()"
local FRAG_RIGHT_BRACKET 	= "()%](%=*)%]"

-- Empty captures in the bracket fragments will set captures #2 and #3 of
-- the produced bracket token with the source offsets of the content INSIDE
-- the brackets.

local function start_brackets()
	return function (ctx, tok)
		actions.push_mode("brackets")(ctx, tok)

		-- Comments and strings are handled by the same bracket
		-- matching rules. All content will be merged into the token
		-- that pushed the brackets mode onto the stack. Bracket
		-- variants are matched according to the length of the
		-- first capture.
	end
end

return Grammar {

	{	'keyword.break', 	'break' 	},
	{	'keyword.goto',		'goto'		},
	{	'keyword.for',		'for'		},
	{	'keyword.in',		'in'		},
	{	'keyword.do',		'do'		},
	{	'keyword.end',		'end'		},
	{	'keyword.while',	'while'		},
	{	'keyword.repeat',	'repeat'	},
	{	'keyword.until',	'until'		},
	{	'keyword.if',		'if'		},
	{	'keyword.then',		'then'		},
	{	'keyword.elseif',	'elseif'	},
	{	'keyword.else',		'else'		},
	{	'keyword.function',	'function'	},
	{	'keyword.local',	'local'		},
	{	'keyword.return',	'return'	},
	{	'keyword.literal',	{'nil', 'false', 'true'}},

	{
		'operator.nary',
		{
			'%-', '%~'
		}
	},

	{
		'operator.binary',
		{
			"%+", --[["%-",]] "%*", "%/%/", "%/", "%^", "%%",
			"%&", "%|", "%>%>", "%<%<",
			"%.%.",
			"%<%=", "%<", "%>%=", "%>", "%=%=", "%~%=",
			--[["%~",]] "and", "or"
		}
	},

	{
		'operator.unary',
		{
			--[["%-",]] "not", "%#", --[["%~"]]
		}
	},

	{
		'keyword.varargs',
		{
			"%.%.%."
		}
	},

	{
		'identifier.label',
		"::" .. "%s*" .. "(" .. FRAG_IDENTIFIER .. ")" .. "%s*" .. "::"
	},

	{
		'numeral',
		ALTS_NUMBER
	},

	{
		'identifier',
		FRAG_IDENTIFIER
	},


	{ '{', "%{" },
	{ '}', "%}" },
	{ '[', "%[" },
	{ ']', "%]" },
	{ '(', "%(" },
	{ ')', "%)" },
	{ '=', "%=" },
	{ ';', "%;" },
	{ ',', "%," },
	{ '.', "%." },
	{ ':', "%:" },

	{ 'whitespace.inline', '[\t ]', 	channel="whitespace"},
	{ 'whitespace.linebreak', '[\r\n]',	channels={"whitespace", "newlines"}},
	{ 'whitespace.other', "%s", 		channel="whitespace" },


	{
		'comment.line',

		{
			-- poisoned alternative, this never produces a token
			FRAG_COMMENT .. FRAG_LEFT_BRACKET,

			-- actual production
			FRAG_COMMENT .. "[^\r\n]*"
		},

		channel = "comments";

		predicates = {
			function (ctx, tok)

				-- if we just used the actual pattern for this
				-- production, it would override any actual
				-- multiline comments because this rule consumes
				-- all characters till the end of the line, and
				-- the produced token would be longer than the
				-- correct multi-line comment token.

				-- To correct this, we insert an alternative
				-- that matches multi-line comments. Alternatives
				-- are matched first-come-first-served, so
				-- the shorter alternative will be matched
				-- because it is ordered before the longer
				-- alternative. This predicate detects a
				-- match of that alternative and poisons the
				-- production if one such match is detected.

				if tok:alt(1) then
					return false, false
				else
					return true
				end
			end
		},

		--skip = true
	},

	-- brackets

	{
		'comment.multiline',

		FRAG_COMMENT .. FRAG_LEFT_BRACKET,

		channel = "comments";

		actions = {
			start_brackets()
		}
	},

	{
		'brackets.close',
		FRAG_RIGHT_BRACKET,
		mode 	= 'brackets',

		actions = {

			actions.merge(),
			actions.pop_mode(),

			function (ctx, tok)
				--if ctx:tokens(-1):id('comment.multiline') then
				--	actions.skip()(ctx)
				--end
			end

		},

		predicates = {
			function (ctx, tok)

				local bracket 	= ctx:tokens(-1)
				local level 	= string.len(bracket:captures(1))
				local my_level	= string.len(tok:captures(2))

				-- Since captures are preserved through merges,
				-- all we have to do here is check the first
				-- capture of the token at the top of the stack
				-- to make sure our closing bracket is really
				-- a match for our opening bracket.

				return level == my_level

			end
		}
	},

	{
		'brackets.content',
		'.',
		merge 	= 'true',
		mode 	= 'brackets'
	},

	-- brackets string

	{
		'string.brackets',
		FRAG_LEFT_BRACKET,
		actions = { start_brackets() }
	},

	-- string escapes

	{
		'string.escape',
		"[\\](.)",
		modes 	= { 'string.single', 'string.double' },
		merge	= true,
	},

	-- single quote string

	{
		'string.single',
		"'",
		push_mode = 'string.single'
	},

	{
		'string.single.char',
		"[^'\r\n]",
		mode 		= 'string.single',
		merge		= true
	},

	{
		'string.single.stop',
		"'",
		merge		= true,
		mode 		= 'string.single',
		pop_mode 	= true
	},

	-- double quote string

	{
		'string.double',
		"\"",
		push_mode 	= 'string.double'
	},

	{
		'string.double.char',
		"[^\"\r\n]",
		mode 		= 'string.double',
		merge		= true
	},

	{
		'string.double.stop',
		"\"",
		mode 		= 'string.double',
		merge		= true,
		pop_mode 	= true
	}
}
