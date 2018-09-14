return function (LuaParser)
	local pf	= require 'eonz.polyfill'
	local table 	= pf.extended 'table'
	local string	= pf.extended 'string'

	LuaParser.OPERATOR_PRECEDENCE = {
		{ arity=2, assoc='right', '^' },
		{ arity=1, assoc='right', 'not', '#', '-', '~' },
		{ arity=2, assoc='left' , '*', '/', '//', '%' },
		{ arity=2, assoc='left' , '+', '-' },
		{ arity=2, assoc='right', '..' },
		{ arity=2, assoc='left' , '<<', '>>' },
		{ arity=2, assoc='left' , '&' },
		{ arity=2, assoc='left' , '~' },
		{ arity=2, assoc='left' , '|' },
		{ arity=2, assoc='left' , '<', '>', '<=', ">=", "~=", "==" },
		{ arity=2, assoc='left' , 'and' },
		{ arity=2, assoc='left' , 'or' },
	}


	do -- init LuaParser.OPERATOR_PRECEDENCE
		for i, level in ipairs(LuaParser.OPERATOR_PRECEDENCE) do
			level.rank = i
		end
	end

	LuaParser.RVALUE_PREDICT_SET = {
		'identifier',
		'('
	}


	LuaParser.RVALUE_PRIME_PREDICT_SET = {
		'[',	-- array index
		'.',	-- member index
	}


	LuaParser.LVALUE_CATEGORY = 'lvalue'


	LuaParser.RVALUE_CATEGORY = 'rvalue'


	LuaParser.STRING_TOKENS = {
		'string.single',
		'string.double',
		'string.brackets',
	}


	LuaParser.INVOCATION_ARGS_PREDICT_SET = {
		'(',	-- direct call
		'{', 	-- table constructor as arg
		-- string as arg
		'string.single',
		'string.double',
		'string.brackets',
	}


	LuaParser.INVOCATION_PRIME_PREDICT_SET = table.join( LuaParser.INVOCATION_ARGS_PREDICT_SET, { ':' })


	LuaParser.SINGLE_TOKEN_EXPRESSION = {
		'string.single',
		'string.double',
		'string.brackets',
		'keyword.literal',
		'numeral',
		'keyword.varargs'
	}


	LuaParser.STATEMENT_STARTING_KEYWORDS = {
		'keyword.do',
		'keyword.goto',
		'keyword.while',
		'keyword.repeat',
		'keyword.if',
		'keyword.for',
		'keyword.function',
		'keyword.local',
		'keyword.break'
	}


	LuaParser.STATEMENT_PREDICT_SET = table.join (
		{ ';', 'identifier.label' },
		LuaParser.RVALUE_PREDICT_SET, -- indicates assignment or function call
		LuaParser.STATEMENT_STARTING_KEYWORDS
	)


	LuaParser.EXPRESSION_PREDICT_SET = table.join (
		LuaParser.RVALUE_PREDICT_SET,
		LuaParser.SINGLE_TOKEN_EXPRESSION,
		{
			'keyword.function',
			'operator.unary',
			'operator.nary',
			'{'
		}
	)


end
