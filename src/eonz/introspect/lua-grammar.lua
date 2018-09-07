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

local function start_brackets()
	return function (ctx, tok)
		actions.push_mode("brackets")(ctx, tok)
	end
end

return Grammar {

	{	'keyword.break', 	'break' 	},
	{	'keyword.goto',		'goto'		},
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
		'identifier',
		FRAG_IDENTIFIER
	},

	{
		'operator.unary',
		{
			"%-", "not", "%#", "%~"
		}
	},

	{
		'operator.binary',
		{
			"%+", "%-", "%*", "%/%/", "%/", "%^", "%%",
			"%&", "%|", "%>%>", "%<%<",
			"%.%.",
			"%<%=", "%<", "%>%=", "%>", "%=%=", "%~%=",
			"%~"
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
		"::" .. "%s?" .. "(" .. FRAG_IDENTIFIER .. ")" .. "%s?" .. "::"
	},

	{
		'numeral',
		ALTS_NUMBER
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

	{ 'WS', "%s", skip=true },


	{
		'comment.line',
		{
			FRAG_COMMENT .. FRAG_LEFT_BRACKET,
			FRAG_COMMENT .. "[^\r\n]*"
		},

		predicates = {
			function (ctx, tok)
				print ("comment: ", tok:alt())

				if tok:alt(1) then
					return false, false
				else
					return true
				end
			end
		}
	},

	-- brackets

	{
		'comment.multiline',

		FRAG_COMMENT .. FRAG_LEFT_BRACKET,

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
			actions.pop_mode()
		},

		predicates = {
			function (ctx, tok)
				local bracket 	= ctx:tokens(-1)
				local level 	= string.len(bracket:captures(1))
				local my_level	= string.len(tok:captures(2))
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
		modes = { 'string.single', 'string.double' }
	},

	-- single quote string

	{
		'string.single.start',
		"'",
		push_mode = 'string.single'
	},

	{
		'string.single.char',
		"[^'\r\n]",
		mode 		= 'string.single',
		merge_alike	= true
	},

	{
		'string.single.stop',
		"'",
		mode = 'string.single',
		pop_mode = true
	},

	-- double quote string

	{
		'string.double.start',
		"\"",
		push_mode = 'string.double'
	},

	{
		'string.double.char',
		"[^\"\r\n]",
		mode 		= 'string.double',
		merge_alike	= true
	},

	{
		'string.double.stop',
		"\"",
		mode = 'string.double',
		pop_mode = true
	}
}
