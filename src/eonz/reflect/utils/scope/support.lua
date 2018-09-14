local eonz		= require 'eonz'

local Token		= eonz.lexer.Token
local SyntaxNode	= eonz.lexer.SyntaxNode
local get_class		= eonz.get_class

local function is_syntax(value)
	return get_class(value) == SyntaxNode
end

local function is_token(value)
	return get_class(value) == Token
end

local function get_identifier_token(value)
	if is_syntax(value) then
		assert(value:roles("identifier"), 'can not get identifier token: syntax rule does not have identifier role')
		value = assert(value:tags("name_token"))
	end

	if is_token(value) then
		assert(value:id('identifier'), 'token was not an identifier token')
		return value
	else
		error('could not get token from: ' .. tostring(get_class(value)) .. " " .. tostring(value))
	end
end

local function get_identifier_text(value)
	return get_identifier_token(value):text()
end

return {
	is_syntax 		= is_syntax;
	is_token		= is_token;
	get_identifier_token 	= get_identifier_token;
	get_identifier_text	= get_identifier_text;
}
