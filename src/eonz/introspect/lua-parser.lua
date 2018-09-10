-- @auto-fold regex /^[\t](local )?(function|[a-zA-Z_]+\s*[=]).*$/ /define_rule {/ /.*self:alternative.*/

local eonz 		= require 'eonz'
local Token 		= require 'eonz.lexer.token'
local Stream 		= require 'eonz.lexer.stream'
local Context 		= require 'eonz.lexer.context'
local GenericLuaParser 	= require 'eonz.lexer.parser'
local grammar		= require 'eonz.introspect.lua-grammar'
local SyntaxNode 	= require 'eonz.lexer.syntax-node'

local LuaParser = eonz.class { 	name	= "eonz::introspect::LuaParser",
				extends	= GenericLuaParser 			}
do
	require('eonz.introspect.lua-parser.constants')(LuaParser)

	function LuaParser:init(opt)
		opt = eonz.options.from(opt, {
			grammar	 	= grammar;
			stream 		= 'default';
		})


		GenericLuaParser.init(self, opt)
	end

	local function define_rule(def)

		local function generator (self, ...)
			self:enter_rule(def.name)

			local result 	= self:leave(def[1](self, ...))
			assert(result, "rule " .. def.name .. " returned nil")
			result:origin(def.name .. (self:trail(1).alternative and ("::" .. self:trail(1).alternative) or ""))
			return result
		end

		LuaParser.RULES = LuaParser.RULES or {}

		LuaParser.RULES[def.name] = {
			name 		= def.name,
			generator	= generator
		}

		LuaParser[def.name] = generator
	end

	define_rule { name = 'chunk',
		function (self)
			local block = self:block()
			self:expect(nil, "unreachable code after return statement")
			return SyntaxNode({
				'chunk'
			}, {block}, {block=block})
		end
	}

	define_rule { name = 'block',
		function (self)
			local stat 	= {}

			while self:peek(LuaParser.STATEMENT_PREDICT_SET) do
				table.insert(stat, self:statement())
			end

			if #stat == 0 then
				stat = SyntaxNode({
					'empty-statement-list-construct', 'statement-list-construct', 'list-construct', 'construct'
				}, stat)
			else
				stat = SyntaxNode({
					'statement-list-construct',  'list-construct', 'construct',
				}, stat)
			end

			local retstat	= self:peek('keyword.return') and self:return_statement()

			if retstat then
				return SyntaxNode({
					'block-construct', 'construct'
				}, { stat, retstat })
			else
				return SyntaxNode({
					'block-construct', 'construct'
				}, { stat })
			end
		end
	}

	require('eonz.introspect.lua-parser.rules.identifiers')	(LuaParser, define_rule)

	-- handles rules for most statements, except those defined in the functions
	-- module.
	require('eonz.introspect.lua-parser.rules.statements')	(LuaParser, define_rule)

	-- handles rules that match expressions and parts of expressions, including
	-- literals and table constants, but not including function invocation
	require('eonz.introspect.lua-parser.rules.expressions')	(LuaParser, define_rule)

	-- matches statements and expressions that define and invoke functions
	require('eonz.introspect.lua-parser.rules.functions')	(LuaParser, define_rule)

	-- handles repeated lists of other rules, such as arguments, params, expressions
	require('eonz.introspect.lua-parser.rules.lists')	(LuaParser, define_rule)

end

return LuaParser
