local json = {
	grammar = require 'eonz.json.grammar',
	parser  = require 'eonz.json.parser',
	Parser  = require 'eonz.json.parser'
}

function json.parse(src, opt)
	opt.source = require('eonz.lexer.info').Source {
		text = src,
		name = opt.source_name or "json",
		lang = json
	}

	return json.Parser(opt):json()
end

return json
