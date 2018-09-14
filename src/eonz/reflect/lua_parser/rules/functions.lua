local eonz = require 'eonz'
local table = eonz.pf.table
local string = eonz.pf.string
local SyntaxNode = require 'eonz.lexer.syntax_node'
return function(LuaParser, define_rule)

	define_rule { name = 'function_name',
		function (self)
			local node = self:peek({'.', ':'}, 2)
				and	self:variable_reference()
				or	self:variable_declaration {
					'function-declaration';
					'declaration';
					'function-name';
				}

			while self:peek('.') do
				node = self:peek({'.', ':'}, 3)
					and	self:indexing_identifier(node)
					or	self:indexing_identifier(node, {
						'member-function-declaration';
						'function-declaration';
						'declaration';
						'function-name';
					})
			end

			if self:peek(':') then
				node = self:method_index(node, {
					'method-function-declaration';
					'member-function-declaration';
					'function-declaration';
					'declaration';
					'function-name';
				})
			end

			return node
		end
	}

	define_rule { name = 'function_body',
		function (self)

			local params, block, kw_end =
				self:param_list({
					'function-parameter',
					'local-variable-declaration',
					'function-parameter-declaration',
					'local-variable'
				}),
				self:block(),
				self:consume('keyword.end')

			return SyntaxNode({
				'function-body-construct', 'construct'
			},{
				params,
				block,
				kw_end
			},{
				declared_locals = assert(params:tags("identifiers"));

				expressions 	= {};
				block_locals	= params:tags("identifiers");
				blocks		= { block };
			})

		end
	}

	define_rule { name = 'invocation_prime',
		function (self, base)
			local target, args, is_method

			if self:peek(':') then
				target = self:method_index(base, {
					'method-identifier-index-expression';
					'identifier-index-expression';
					'expression';
					'lvalue-expression';
				}):extend({}, {
					expressions = { target }
				})


				--[[SyntaxNode({
					'invocation-target-construct', 'method-invocation-target', 'target-construct', 'construct'
				},{
					self:method_index(base)
				})--]]

				is_method = true
			else
				target = base --[[ SyntaxNode({
					'invocation-target-construct', 'function-invocation-target', 'target-construct', 'construct'
				},{
					base
				})--]]

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
				valid_statement		= true;
				expressions		= table.join({target}, assert(args:tags("expressions")));
			})
		end
	}

	define_rule { name = 'invocation_args',
		function (self, is_method)

			self:expect(LuaParser.INVOCATION_ARGS_PREDICT_SET,
				"expected function arguments, table-as-arguments, or string-as-arguments")

			if self:peek('(') then
				local _1, _2
				_1 = self:consume_optional('(')

				if self:peek(LuaParser.EXPRESSION_PREDICT_SET) then
					local args = self:expression_list()
					_2 = self:consume(")")

					return SyntaxNode({
						'populated-list-arguments-construct',
						'list-arguments-construct',
						'arguments-construct',
						'list-construct',
						'construct',
						(is_method and 'method-' or '') .. 'arguments-construct'
					},{ _1, args, _2 },{
						expressions 	= assert(args:tags("expressions"));
					})
				else
					_2 = self:consume(")")
					return SyntaxNode({
						'empty-list-arguments-construct',
						'list-arguments-construct',
						'arguments-construct',
						'list-construct',
						'construct',
						(is_method and 'method-' or '') .. 'arguments-construct'
					},{ _1, _2 }, { expressions = {} })
				end

			elseif self:peek('{') then
				local expr = self:table_constructor()

				return SyntaxNode({
					'table-arguments-construct',
					'arguments-construct',
					'construct',
					(is_method and 'method-' or '') .. 'arguments-construct'
				},{ expr }, { expressions = { expr }; })

			elseif self:peek(LuaParser.STRING_TOKENS) then
				local expr = self:expression()

				return SyntaxNode({
					'string-arguments-construct',
					'arguments-construct',
					'construct',
					(is_method and 'method-' or '') .. 'arguments-construct'
				},{ expr },{ expressions = { expr };})
			end

		end
	}
end
