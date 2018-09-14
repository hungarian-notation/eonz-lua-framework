
local eonz = require 'eonz'
local SyntaxNode = require 'eonz.lexer.syntax-node'
return function(LuaParser, define_rule)

	define_rule { name = 'identifier',
		function (self, roles)
			roles = roles or { "id" }
			roles.primary = roles.primary or "id"
			local id = self:consume('identifier')
			return SyntaxNode(table.join({
				roles.primary .. ' \"' .. id:text() .. '\"', "identifier", "id"
			}, roles or {}), {id}, { name_token = id })
		end
	}

	define_rule { name = 'variable_reference',
		function (self, roles)
			local identifier = self:identifier()

			local roles = table.join(roles or {}, {
				'variable-reference \"' .. identifier:children()[1]:text() .. '\"';
				'reference';
				'variable';
				'identifier';
				'expression';
				'variable-reference';
				'lvalue-expression';
				'rvalue-expression';
			})

			local tags = {
				name 		= identifier;
				value_category	= LuaParser.LVALUE_CATEGORY;
			}

			return identifier:extend(roles, tags)
		end
	}

	define_rule { name = 'variable_declaration',
		function (self, roles)
			roles = table.join((roles or {}), {
				'variable-declaration', 'declaration', 'identifier'
			})

			local identifier_roles = {
				"variable-identifier";
				table.contains(roles, 'declaration') and 'declaration' or nil
			}

			local id = self:identifier(identifier_roles)

			--return SyntaxNode(roles,{
			--	id
			--},{
			--	name = id;
			--	added_roles = roles ;
			--})

			return id:extend(roles, {
				name = id;
			})
		end
	}

	define_rule { name = 'method_index',
		function (self, left, roles)
			roles = roles or {}
			roles.op = roles.op or ":"
			roles.top_role = roles.top_role or roles[1] or  "method-index-identifier"

			return self:indexing_identifier(left, roles)
		end
	}

	define_rule { name = 'indexing_identifier',
		function (self, left, roles)
			roles = roles or {
				op = '.'
			}

			roles.top_role = roles.top_role or "index-identifier"

			assert(left, "indexing_identifier requires index target as argument")
			assert(left:roles({ 'rvalue-expression', 'expression', 'index-construct', 'variable-declaration' }), "invalid index target: " .. tostring(left))

			--left = SyntaxNode({
			--	'index-target-construct', 'target-construct', 'construct'
			--}, { left })

			left = left:extend {
				'index-target-construct', 'target-construct', 'construct'
			}

			local _1, id = self:consume(roles.op), self:identifier({
				"index-identifier";
				table.contains(roles, 'declaration') and 'declaration' or nil
			})

			local final_roles = table.join(roles, {
				'index-construct', 'construct'
			})

			return SyntaxNode(final_roles,{
				left, _1, id
			},{
				target		= left;
				name 		= id;
				index 		= id;
				value_category	= LuaParser.LVALUE_CATEGORY;
			})
		end
	}

end
