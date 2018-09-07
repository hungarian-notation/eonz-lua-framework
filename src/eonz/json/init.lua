local json = {
	grammar = require "eonz.json.grammar",
	parser  = require "eonz.json.parser",
	Parser  = require "eonz.json.parser"
}

function json.parse(src, opt)
	return json.Parser(src, opt):json()
end

return json
