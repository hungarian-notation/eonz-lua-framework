local eonz = require "eonz"
local SyntaxNode = require 'eonz.lexer.syntax-node'
return function(LuaParser, define_rule)

	define_rule { name = 'function_name',
		function (self)
			local node = self:variable_reference()

			while self:peek('.') do
				node = self:indexing_identifier(node)
			end

			if self:peek(':') then
				node = self:method_index(node, {
					'method-declaration', 'declaration'
				})
			end

			return node
		end
	}

	define_rule { name = 'function_body',
		function (self)

			return SyntaxNode({
				'function-body-construct', 'construct'
			},{
				self:param_list({
					'function-parameter',
					'local-variable-declaration',
					'function-parameter-declaration',
					'local-variable'
				}), self:block(), self:consume('keyword.end')
			})

		end
	}

	define_rule { name = 'invocation_prime',
		function (self, base)
			local target, args, is_method

			if self:peek(':') then
				target = SyntaxNode({
					'invocation-target-construct', 'method-invocation-target', 'target-construct', 'construct'
				},{
					self:method_index(base)
				})

				is_method = true
			else
				target = SyntaxNode({
					'invocation-target-construct', 'target-construct', 'construct'
				},{
					base
				})

				is_method = false
			end

			args = self:invocation_args(is_method)

			local roles = {
				'invocation-expression', 'expression', 'rvalue-expression', LuaParser.VARIABLE_LENGTH_ROLE
			}

			if is_method then
				roles = table.join({ 'method-invocation-expression' }, roles)
			else
				roles = table.join({ 'function-invocation-expression' }, roles)
			end

			return SyntaxNode( roles,
			{
				target, args
			},{
				args 			= args,
				is_method 		= is_method,
				calling_convention	= is_method and "method" or "normal",
				value_category		= LuaParser.RVALUE_CATEGORY,
				valid_statement		= true
			})
		end
	}

	define_rule { name = 'invocation_args',
		function (self, is_method)

			self:expect(LuaParser.INVOCATION_ARGS_PREDICT_SET,
				"expected function arguments, table-as-arguments, or string-as-arguments")

			if self:consume_optional('(') then
				if self:peek(LuaParser.EXPRESSION_PREDICT_SET) then
					local args = self:expression_list()
					self:consume(")")
					return SyntaxNode({
						'arguments-construct',
						'list-construct',
						'construct',
						(is_method and 'method-' or '') .. 'arguments-list-construct'
					},{ args })
				else
					self:consume(")")
					return SyntaxNode({
						'empty-arguments-list-construct',
						'arguments-construct',
						'list-construct',
						'construct',
						(is_method and 'method-' or '') .. 'arguments-list-construct'
					},{})
				end
			elseif self:peek('{') then
				local expr = self:table_constructor()

				return SyntaxNode({
					'table-arguments-construct',
					'arguments-construct',
					'construct',
					(is_method and 'method-' or '') .. 'arguments-list-construct'
				},{ expr })

			elseif self:peek(LuaParser.STRING_TOKENS) then
				local expr = self:expression()

				return SyntaxNode({
					'string-arguments-construct',
					'arguments-construct',
					'construct',
					(is_method and 'method-' or '') .. 'arguments-list-construct'
				},{ expr })
			end

		end
	}
end
