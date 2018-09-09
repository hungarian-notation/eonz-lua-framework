-- @auto-fold regex /^[\t](local )?(function|[a-zA-Z_]+\s*[=]).*$/ /define_rule {/ /.*self:alternative.*/

local eonz = require "eonz"
local SyntaxNode = require 'eonz.lexer.syntax-node'
return function(LuaParser, define_rule)

	LuaParser.VARIABLE_LENGTH_ROLE 		= 'variable-length-expression'
	LuaParser.EXPANSION_CONTEXT_ROLE 	= 'expansion-context'

	function LuaParser.flatten_varargs(node)
		-- some expressions, like function invocations and the
		-- varargs literal, may expand into multiple values when
		-- in an expression-list context. This function strips
		-- them of the `variable-length-expression` property
		-- to indicate that they could not expand in their current
		-- position

		node:revoke { LuaParser.VARIABLE_LENGTH_ROLE }
		return node
	end

	local function get_precedence(operator, arity)
		for i, level in ipairs(LuaParser.OPERATOR_PRECEDENCE) do
			if table.contains(level, operator) and ((not arity) or (arity == level.arity)) then
				return table
			end
		end

		return nil
	end

	local function is_operator_sequence(expression)
		return expression:roles('operation')
	end

	local function split_operator(sequence, expr)
		if expr:roles('binary-operation') then
			table.insert(sequence, SyntaxNode({
				'operand'
			},{
				expr:tags('left')
			}))

			table.insert(sequence, SyntaxNode({
				'binary \"' .. expr:tags('op'):text() .. '\"', 'binary-operator', 'operator'
			},{
				expr:tags('op')
			},{
				arity = 2;
				op = expr:tags('op');
			}))

			expr = expr:tags('right')
		else
			table.insert(sequence, SyntaxNode({
				'unary \"' .. expr:tags('op'):text() .. '\"', 'unary-operator', 'operator'
			},{
				expr:tags('op')
			},{
				arity = 1;
				op = expr:tags('op');
			}))

			expr = expr:tags('operand')
		end

		return expr
	end

	local function expand_element(expanded, element)
		if element:roles('operator') then
			table.insert(expanded, element)
		else
			local content = element:children()[1]

			if content:roles('operation-sequence') then
				for i, member in ipairs(content:children()) do
					table.insert(expanded, member)
				end
			else
				table.insert(expanded, element)
			end
		end
	end

	local function expand_operations(expr)
		local sequence = {}

		while SyntaxNode:is_instance(expr) and (expr:roles({'binary-operation', 'unary-operation'})) do
			expr = split_operator(sequence, expr)
		end

		table.insert(sequence, SyntaxNode({
			'operand'
		},{
			expr
		}))

		local expanded = {}

		for i, element in ipairs(sequence) do
			expand_element(expanded, element)
		end

		return expanded
	end

	local function process_operator_sequence(expr)
		return SyntaxNode({
			'operation-sequence'
		}, expand_operations(expr))
	end

	local function extract_operand(rule)
		if rule:roles('operand') then
			rule = rule:children()[1]
		end

		return LuaParser.flatten_varargs(rule)
 	end

	local function rebuild_operator_tree(sequence)
		local original_sequence = table.copy(sequence)

		for i, precedence in ipairs(LuaParser.OPERATOR_PRECEDENCE) do
			local arity 	= precedence.arity
			local assoc 	= precedence.assoc
			local change

			repeat
				change 	= false

				local from 	= assoc == 'left' and 1 or #sequence
				local to 	= assoc == 'left' and #sequence or 1
				local step	= to > from and 1 or -1

				for j = from, to, step do
					local part = sequence[j]
					local op = part:roles('operator')
						and part:tags('arity') and part:tags('arity') == arity
						and part:tags('op')
					if op and table.contains(precedence, op:text()) then


						if arity == 1 then
							-- condense unary
							local pivot = j

							local op, r =
								table.remove(sequence, pivot),
								extract_operand(table.remove(sequence, pivot))
							table.insert(sequence, pivot, SyntaxNode({
								'unary-operation',
								'operation',
								'operation-expression',
								'expression',
								'rvalue-expression',
							},{
								op, r
							},{
								op 		= op;
								operands	= { r };
								sequence 	= original_sequence;
							}))

							change = true
							break
						elseif arity == 2 then
							-- condense binary
							local pivot = j - 1

							local l, op, r =
								extract_operand(table.remove(sequence, pivot)),
								table.remove(sequence, pivot),
								extract_operand(table.remove(sequence, pivot))
							table.insert(sequence, pivot, SyntaxNode({
								'binary-operation',
								'operation',
								'operation-expression',
								'expression',
								'rvalue-expression',
							},{
								op, l, r
							},{
								op 		= op;
								operands	= { l, r };
								sequence 	= original_sequence;
							}))

							change = true
							break
						end
					end
				end
			until not change
		end

		return sequence
	end

	define_rule { name = 'expression',
		function (self)
			local base = self:operand_expression()
			if is_operator_sequence(base) then
				local operations 	= expand_operations(base)
				local tree 		= rebuild_operator_tree(table.copy(operations))


				assert(#tree ~= 0, 'sequence reduced to empty list: ' .. table.tostring(operations))
				assert(#tree == 1, 'tree did not reduce to single expression: ' .. table.tostring(tree))

				base = tree[1]
			end
			return base
		end
	}

	--[[--
		operand_expression is expression without the operator processing.
	--]]--
	define_rule { name = 'operand_expression',
		function (self)
			local base = self:expression_base()

			while self:peek({'operator.binary', 'operator.nary'}) do
				local op 	= self:consume({'operator.binary', 'operator.nary'})
				local rest	= self:operand_expression()

				local precedence = get_precedence(op, 2)

				base = SyntaxNode({
					'binary-operation \"' .. op:text() .. '\"', 'binary-operation', 'expression', 'operation', 'binary'
				},{ base, op, rest },{
					left 		= base;
					right 		= rest;
					op		= op;
					precedence	= get_precedence(op:text(), 2);
				})
			end

			return  base
		end
	}

	define_rule { name = 'expression_base',
		function (self)
			if self:peek(LuaParser.SINGLE_TOKEN_EXPRESSION) then 				self:alternative "single token"

				if self:peek('string.brackets') then

					local tok 	= self:consume('string.brackets')
					local content 	= tok:source():sub(tok:captures(2), tok:captures(3) - 1)

					return SyntaxNode({
						'string  \"' .. content .. '\"',
						'string-literal',
						'literal-expression',
						'expression',
						'rvalue-expression',
						'constexpr'
					},{
						tok
					},{
						text 		= content;
						value		= content;
						constexpr	= 'string';
					})

				elseif self:peek({ 'string.single', 'string.double' }) then

					local tok 	= self:consume({ 'string.single', 'string.double' })
					local content 	= tok:text():sub(2, -2)

					return SyntaxNode({
						'string  \"' .. content .. '\"',
						'string-literal',
						'literal-expression',
						'expression',
						'rvalue-expression',
						'constexpr'
					},{
						tok
					},{
						text 		= content;
						value		= content;
						constexpr	= 'string';
					})

				elseif self:peek('numeral') then


					local tok = self:consume('numeral')

					return SyntaxNode( table.join({ 'number \"' .. tok:text() .. '\"'
					},{
						'number-literal',
						'literal-expression',
						'expression',
						'rvalue-expression',
						'constexpr'
					}),{
						tok
					},{
						value 		= tonumber(tok:text());
						constexpr	= 'number';
					})

				elseif self:peek('keyword.literal') then
					local tok = self:consume('keyword.literal')

					if tok:text() == 'nil' then
						return SyntaxNode({
							'nil-literal',
							'nil-expression',
							'literal-expression',
							'expression',
							'rvalue-expression',
							'constexpr'
						},{
							tok
						},{
							value		= nil;
							constexpr 	= 'nil';
						})
					else
						local variant = tok:text()

						return SyntaxNode({
							'boolean-' .. variant .. '-literal',
							'boolean-' .. variant .. '-literal-expression',
							'boolean-literal-expression',
							'literal-expression',
							'boolean-expression',
							'expression',
							'rvalue-expression',
							'constexpr'
						},{
							tok
						},{
							value 		= (tok:text() == 'true');
							constexpr 	= 'boolean';
						})
					end

				elseif self:peek('keyword.varargs') then
					local tok = self:consume('keyword.varargs')

					return SyntaxNode({
						'varargs-literal',
						'literal-expression',
						'expression',
						'varargs-expression',
						LuaParser.VARIABLE_LENGTH_ROLE
					}, { tok })

				else
					error('bug in lua parser: out of alternatives')
				end

			elseif self:peek('keyword.function') then 				self:alternative "anonymous function"

				return SyntaxNode({
					'anonymous-function',
					'function-literal',
					'literal-expression',
					'expression',
					'rvalue-expression'
				},{
					self:consume('keyword.function'),
					self:function_body()
				})

			elseif self:peek({ 'operator.unary', 'operator.nary' }) then 		self:alternative "unary operator"

				local op 	= self:consume({ 'operator.unary', 'operator.nary' })
				local expr	= self:operand_expression()

				return SyntaxNode({
					'unary-operation \"' .. op:text() .. '\"',
					'unary-operation',
					'operation',
					'unary',
					'expression',
					'rvalue-expression'
				},{
					op, expr
				},{
					operand		= expr;
					op 		= op;
					expression 	= expr;
					precedence	= get_precedence(op:text(), 2);
				})

			elseif self:peek('{') then 						self:alternative "table constructor"

				return self:table_constructor()

			elseif self:peek(LuaParser.RVALUE_PREDICT_SET) then 				self:alternative "rvalue"
				local rvalue = self:rvalue()

				return rvalue

				--if rvalue.value_category == LuaParser.RVALUE_CATEGORY then
					--[[return SyntaxNode({
						'invocation-result', 'expression', rvalue.valid_statement and 'invocation-result' or 'rvalue-expression'
					},{
						rvalue
					})]]
				--else
					--[[return SyntaxNode({
						'lookup-result', 'expression', 'lvalue-expression'
					},{
						rvalue
					})]]
				--end
			else
				self:syntax_error('unexpected token')
			end

		end
	}

	define_rule { name = 'lvalue',
		function (self)
			local rvalue = self:rvalue()

			if rvalue:tags('value_category') ~= LuaParser.LVALUE_CATEGORY then
				self:syntax_error("result of expression is not an lvalue", { after=true })
			end

			return rvalue
		end
	}

	define_rule { name = 'rvalue',
		function (self, lvalue_or_invocation)
			local value = self:rvalue_base()

			local is_lvalue 	= value:roles('lvalue-expression')
			local is_invocation 	= value:tags('valid_statement')

			if lvalue_or_invocation and not (is_lvalue or is_invocation) then
				self:expect(table.join(LuaParser.RVALUE_PRIME_PREDICT_SET, LuaParser.INVOCATION_PRIME_PREDICT_SET),
					"expected more here, this must be an lvalue or an invocation")
			end

			while self:peek(LuaParser.RVALUE_PRIME_PREDICT_SET) or self:peek(LuaParser.INVOCATION_PRIME_PREDICT_SET) do
				if self:peek(LuaParser.RVALUE_PRIME_PREDICT_SET) then
					--local prime = self:rvalue_prime()

					--[[value = {
						value, prime,
						prefix 		= value,
						prime		= prime,
						lookup 		= prime,
						value_category	= LuaParser.LVALUE_CATEGORY,
						valid_statement	= false
					}]]

					LuaParser.flatten_varargs(value)
					value = self:rvalue_prime(value)
				elseif self:peek(LuaParser.INVOCATION_PRIME_PREDICT_SET) then
					--local prime =

					--[[value = {
						value, prime,
						prefix 		= value,
						prime		= prime,
						invocation	= prime,
						value_category	= LuaParser.RVALUE_CATEGORY,
						valid_statement	= true
					}]]

					LuaParser.flatten_varargs(value)
					value = self:invocation_prime(value);
				end
			end

			return value
		end
	}

	define_rule { name = 'rvalue_base',
		function (self)
			self:expect({"(", "identifier"}, 'expected lvalue or rvalue')

			if self:peek('(') then
				local expr = {
					self:consume('('),
					LuaParser.flatten_varargs(self:expression()),
					self:consume(')'),
				}

				return SyntaxNode({
					'expression', 'rvalue-expression'
				}, expr, {
					expression 	= expr[2];
					value		= expr[2];
					value_category	= LuaParser.RVALUE_CATEGORY;
				})
			else
				return self:variable_reference()
			end
		end
	}

	define_rule { name = 'rvalue_prime',
		function (self, base)
			if self:peek('[') then
				local expr = {
					self:consume('['),
					LuaParser.flatten_varargs(self:expression()),
					self:consume(']')
				}

				expr[2]:extend {
					'index-value-expression'
				}

				return SyntaxNode({
					'value-index-expression', 'lvalue-expression', 'rvalue-expression', 'lookup', 'expression'
				},{
					base, value, prime
				},{
					target		= base,
					value_category	= LuaParser.LVALUE_CATEGORY,
					valid_statement	= false
				})
			else
				return self:indexing_identifier(base, {
					'identifier-index-expression', 'lvalue-expression', 'rvalue-expression', 'lookup', 'expression'
				}):extend({},{
					target		= base,
					value_category	= LuaParser.LVALUE_CATEGORY,
					valid_statement	= false
				})
			end
		end
	}

	define_rule { name = 'table_constructor',
		function (self)
			local open 	= self:consume("{")

			local next_array	= 1
			local fields		= {}

			while not self:peek("}") do

				local bracketed_index 	= self:peek('[')
				local named_index	= self:peek('identifier', 1) and self:peek('=', 2)
				local indexed

				if bracketed_index or named_index then

					if bracketed_index then
						local _1, expr, _2, kw_eq, value_expr =
							self:consume('['),
							LuaParser.flatten_varargs(self:expression()),
							self:consume(']'),
							self:consume('='),
							LuaParser.flatten_varargs(self:expression());

						indexed = SyntaxNode({
							'array-index-table-field',
							'table-field-construct',
							'construct',
							'index-table-field',
						}, {
							_1, expr, _2, kw_eq, value_expr
						}, {
							key 		= expr,
							key_expression 	= expr,
							key_value	= expr,
							value 		= value_expr
						})
					else
						local id, kw_eq, value_expr =
							self:identifier(),
							self:consume('='),
							LuaParser.flatten_varargs(self:expression());

						indexed = SyntaxNode({
							'identifier-index-table-field',
							'table-field-construct',
							'construct',
							'index-table-field'
						},{
							id, kw_eq, value_expr
						},{
							key 		= id;
							key_identifier 	= id;
							value 		= value_expr;
						})
					end
				else
					local expression = self:expression()

					indexed = expression:wrap ({
						'array-field',
						'table-field-construct',
						'construct',
						'positional-table-field'
					},{
						value = expression
					})
				end

				table.insert(fields, indexed)

				if not self:consume_optional({ ',', ';' }) then
					break
				end
			end

			for i = 1, #fields - 1 do
				LuaParser.flatten_varargs(fields[i])
				LuaParser.flatten_varargs(fields[i]:tags('value'))
			end

			if #fields > 0 and (fields[#fields]):roles('array-field') then
				fields[#fields]:extend { LuaParser.EXPANSION_CONTEXT_ROLE }
			end

			fields = SyntaxNode({
				'table-field-list-construct', 'list-construct', 'construct', LuaParser.EXPANSION_CONTEXT_ROLE
			}, fields)

			return SyntaxNode({
				'table-expression', 'table-literal', 'literal-expression', 'expression', 'rvalue-expression'
			},{
				open, fields, self:consume("}")
			},{
				fields = fields
			})
		end
	}

end
