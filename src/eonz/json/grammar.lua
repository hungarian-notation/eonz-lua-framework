local eonz	= require 'eonz'
local table 	= eonz.pf.table
local string	= eonz.pf.string
local actions	= require 'eonz.lexer.actions'
local Grammar	= require 'eonz.lexer.grammar'

-- Construct Numerical Rules

local  	DIGITS	= '[%d]+'
local  	FRACT	= '[.]' .. DIGITS
local	SIGN	= '[+-]'
local 	OPTSIGN	= SIGN .. '?'
local 	EXP 	= '[eE]' .. OPTSIGN .. DIGITS
local  	INT	= OPTSIGN .. DIGITS
local 	DEC	= INT .. FRACT
local 	INT_EXP	= INT .. EXP
local 	DEC_EXP	= DEC .. EXP

return Grammar {

	{{ 'object.start', 	"'{'"}, 	'%{' 			},
	{{ 'object.stop', 	"'}'"}, 	'%}' 			},
	{{ 'array.start', 	"'['"}, 	'%[' 			},
	{{ 'array.stop', 	"']'"}, 	'%]' 			},
	{  'whitespace',			'%s+', skip=true	},
	{{ 'sep.pair', 		"':'"},		'%:'			},
	{{ 'sep.list', 		"','"},		'%,'			},

	-- Values -------------------------------------------------------------

	{
		'constant',
		{ 'true', 'false', 'null' }
	},

	{
		'number',
		{
			DEC_EXP,
			INT_EXP,
			DEC,
			INT
		}
	},

	-- String Handling ----------------------------------------------------

	{
		'string.start',
		'"',
		display 	= 'string',
		push_mode 	= 'string'
	},

	{
		'string.single.start',
		'\'',
		display 	= 'string',
		push_mode 	= 'single-string'
	},

	{
		'string.character',
		{
			'[^\r\n\\"]+'			-- regular character
		},

		modes = { 'string' },
		actions = {
			actions.merge_alike()
		}
	},

	{
		'string.single.character',
		{
			'[^\r\n%\\%\']+'			-- regular character
		},

		modes = { 'single-string' },
		actions = {
			actions.merge_alike()
		}
	},

	{
		'string.escape',
		{
			'[\\](["\\/bnfrt])',		-- escape sequence
			'[\\][u]([%x][%x][%x][%x])'	-- hex escape sequence
		},

		modes = { 'string', 'single-string', 'error-string' }
	},

	{
		'string.stop',
		'"',
		modes = { 'string' },
		display  = 'string',
		pop_mode = true
	},

	{
		'string.single.stop',
		'\'',
		modes = { 'single-string', },
		display  = 'single-string',
		pop_mode = true
	},

	{
		'error.string.linebreak',
		display = 'illegal linebreak',
		'[\r\n]',
		mode = 'string',
		error = true
	},

	{
		'error.unquoted.stop',
		{
			'%s'
		},
		mode = 'error-string',
		error = true,
		display = 'unquoted identifier terminator',
		actions = {
			actions.pop_mode(),
			actions.virtual()
		}
	},

	{
		'error.unquoted.start',
		{
			'[^%s]'
		},
		error = true,
		display = 'illegal unquoted identifier',
		actions = {
			actions.push_mode('error-string'),
			actions.virtual()
		}
	},

	{
		'error.unquoted',
		{
			'[^%s]'
		},
		mode = 'error-string',
		error = true,
		display = 'illegal unquoted character'
	},

}
