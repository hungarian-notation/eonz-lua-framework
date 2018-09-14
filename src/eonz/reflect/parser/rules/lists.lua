-- @auto-fold regex /^[\t](local )?(function|[a-zA-Z_]+\s*[=]).*$/ /define_rule {/ /.*self:alternative.*/

local eonz = require 'eonz'
local table = eonz.pf.table
local string = eonz.pf.string
local SyntaxNode = require 'eonz.lexer.syntax_node'
return function(LuaParser, define_rule)

	define_rule { name = 'expression_list',
		function (self, roles)
			local expressions = {
				self:expression()
			}

			while self:consume_optional(',') do
				table.insert(expressions, self:expression())
			end

			local final_roles = table.join((roles or {}), {
				'expression-list',  'list-construct', 'construct', LuaParser.EXPANSION_CONTEXT_ROLE
			})

			for i = 1, #expressions - 1 do
				LuaParser.flatten_varargs(expressions[i])
			end

			return SyntaxNode(final_roles, expressions, { expressions = expressions })
		end
	}

	define_rule { name = 'name_list',
		function (self, roles, list_roles)

			if (type(roles) == 'string') then
				roles = { roles }
			end

			list_roles = list_roles or { assert(roles and roles[1]) .. '-list' }
			list_roles = table.join(list_roles, {
				'list-construct', 'construct'
			})

			local names 	= {}

			local function next()
				table.insert(names, self:variable_declaration(roles))
			end

			next()

			while self:peek(',', 1) and self:peek('identifier', 2) do
				self:consume(',')
				next()
			end

			return SyntaxNode(list_roles, names, {
				identifiers = names;
			})
		end
	}

	define_rule { name = 'param_list',

		function (self, roles)
			if (type(roles) == 'string') then
				roles = { roles }
			end

			local _1, _2
			_1 = self:consume('(')

			local names 	= self:peek('identifier', 1) and self:name_list(roles or {'parameter'})
			local varargs 	= nil

			if not names then
				names = SyntaxNode({
					'empty-names-list', 'names-list', 'list-construct', 'construct'
				},{},{empty=true, identifiers={}})
			end

			if self:peek('keyword.varargs') or self:consume_optional(',') then
				varargs = self:consume('keyword.varargs')
				_2 = self:consume(')')

				return SyntaxNode({
					'parameter-list', 'list-construct', 'construct'
				},{
					_1, names, varargs, _2
				},{
					identifiers = assert(names:tags("identifiers"));
					names = names,
					varargs = varargs
				})
			else

				_2 = self:consume(')')
				return SyntaxNode({
					'parameter-list', 'list-construct', 'construct'
				},{
					_1, names, _2
				},{
					identifiers = assert(names:tags("identifiers"));
					names = names,
					varargs = false
				})
			end

		end
	}

end
