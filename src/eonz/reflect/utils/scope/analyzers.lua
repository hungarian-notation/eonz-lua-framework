return function(ScopeContext)
	local eonz 		= require 'eonz'
	local support 		= require 'eonz.reflect.utils.scope.support'
	local Value 		= require 'eonz.reflect.utils.value'
	local ValueReference 	= require 'eonz.reflect.utils.value_reference'
	local IndexingReference = require 'eonz.reflect.utils.indexing_reference'
	local Variable 		= require 'eonz.reflect.utils.variable'



	local CONSTEXPR_EXPRESSIONS = {
		'string-literal';
		'number-literal';
		'boolean-literal';
		'nil-literal';
	}

	local INDEX_REFERENCE_ROLES = {
		'value-index-expression';
		'identifier-index-expression';
	}

	local INVOCATION_REFERENCE_ROLES = {
		'invocation-expression';
	}

	local VARARGS_EXPRESSION = {
		'varargs-literal';
	}

	local OPERATION_EXPRESSION = {
		'operation-expression';
	}

	local TABLE_EXPRESSION = {
		'table-expression';
	}

	local WRAPPED_EXPRESSIONS = {
		'wrapped-expression';
	}

	function ScopeContext:analyze_expression(expression)
		assert(expression:roles("expression"), "not an expression: " .. tostring(expression))

		if expression:roles(CONSTEXPR_EXPRESSIONS) then
			return Value.make_static {
				scope 	= self;
				syntax 	= expression;
			}

		elseif expression:roles(VARARGS_EXPRESSION) then
			return Value {
				scope 		= self;
				syntax 		= expression;
				expandable 	= true;
				dynamic		= true;
				display		= "«varargs»"
			}

		elseif (expression:roles('function-literal')) then
			return self:analyze_function_body(expression:rules()[1])

		elseif (expression:roles('variable-reference')) then
			return self:create_reference(expression, {
				direction = "read"
			})

		elseif expression:roles(WRAPPED_EXPRESSIONS) then
			return self:analyze_expression(assert(expression:tags('expression')))

		elseif expression:roles(INDEX_REFERENCE_ROLES) then
			return self:analyze_index_expression(expression)

		elseif expression:roles(INVOCATION_REFERENCE_ROLES) then
			return self:analyze_invocation(expression)

		elseif expression:roles(OPERATION_EXPRESSION) then
			return self:analyze_operation_expression(expression)

		elseif expression:roles(TABLE_EXPRESSION) then

			local sub_expressions = expression:tags("expressions")

			if sub_expressions then
				self:analyze_expressions(sub_expressions)
			end

			return Value.make_dynamic {
				scope 	= self;
				syntax 	= expression;
				type	= 'table';
			}

		else
			error("UNKNOWN EXPRESSION: " .. expression:name())
		end

		error('failed to return value')
	end

	-- some operators have a static result type
	local OPERATOR_STATIC_TYPING = {
		['#'] 	= 'number';
		['not'] = 'boolean';
		['==']	= 'boolean';
		['~=']	= 'boolean';
		['<']	= 'boolean';
		['>']	= 'boolean';
		['<=']	= 'boolean';
		['>=']	= 'boolean';
	}

	local IS_EQUALITY_OPERATOR = {
		['=='] 	= true;
		['~=']	= true;
	}



	function ScopeContext:analyze_operation_detail(op, operands)
		local	known_type	= OPERATOR_STATIC_TYPING[op.id]
		local	category	= "result";

		if IS_EQUALITY_OPERATOR[op.id] then
			assert(#operands == 2)
			local l, r = operands[1], operands[2]

			if l:known_type() and r:known_type() and l:value_type() ~= r:value_type() then
				-- comparison operator between two different
				-- types has known result, as metamethods are
				-- only invoked when both values have the same
				-- metamethod.

				-- In this case, the code is likely an error,
				-- e.g. `not x == y` instead of `x ~= y`

				return Value.make_static {
					scope		= self;
					syntax 		= op.syntax;
					static_type	= 'boolean';
					static_value	= op.id == '~=';
					tautological	= true;
				}
			end
		end

		return Value.make_dynamic {
			scope 			= self;
			syntax 			= op.syntax;
			dynamic_category	= category;
			type			= known_type;
		}
	end

	function ScopeContext:analyze_operation_expression(expression)
		local operator 		= assert(expression:tags("op"))
		local operator_arity	= assert(operator:tags("arity"))
		local operator_token	= assert(operator:tags("op"))
		local operator_text	= operator_token:text()

		local op = {
			syntax 	= expression;
			token 	= operator_token;
			id	= operator_text;
			arity	= operator_arity;
		}

		local operands 		= assert(expression:tags("operands"))
		local operand_values 	= self:analyze_expressions(operands)

		return self:analyze_operation_detail(op, operand_values)
	end

	function ScopeContext:analyze_index_expression(expression)
		local target 	= assert(expression:tags('target'))
		local index 	= assert(expression:tags('index'))

		if expression:roles('identifier-index-expression') then
			local target_value = self:analyze_expression(target)
			if target_value then

				return self:create_index_reference(target_value, {
					value		= support.get_identifier_token(index):text();
					type		= 'string';
					identifier	= support.get_identifier_token(index);
					token 		= support.get_identifier_token(index);
					method		= not not expression:roles('method-identifier-index-expression');
				})
			end
		elseif expression:roles('value-index-expression') then
			if index:tags('constexpr') then
				-- we can continue static analysis
				local target_value = self:analyze_expression(target)

				if target_value then
					return self:create_index_reference(target_value, {
						value	= index:tags('value');
						type	= index:tags('constexpr');
						method	= false;
					})
				end
			else
				-- dynamic index
				self:analyze_expression(index)
				self:analyze_expression(target)
			end
		end

	end

	function ScopeContext:analyze_invocation(expression)
		local expressions	= assert(expression:tags("expressions"))
		local invoked 		= assert(#expressions >= 1 and expressions[1])
		local arguments		= self:analyze_expressions(eonz.table.slice(expressions, 2))

		-- ana
		local invoked_value 	= assert(self:analyze_expression(invoked))

		return self:create_invocation(invoked_value, {
			arguments = arguments
		})
	end

	function ScopeContext:analyze_expressions(expressions)
		local results = {}

		for i, exp in ipairs(expressions) do
			results[i] = self:analyze_expression(exp)
		end

		return results
	end

	function ScopeContext:analyze_function_body(body, inject_locals)
		assert(body:roles('function-body-construct'))

		local expressions 	= assert(body:tags("expressions"))
		local blocks		= assert(body:tags("blocks"))
		local block_locals	= assert(body:tags("block_locals"))

		-- first, we analyze the expressions
		self:analyze_expressions(expressions);
		-- then, we analyze the blocks
		self:analyze_statement_blocks(blocks, block_locals, inject_locals);
	end

	function ScopeContext:analyze_function_statement(statement)

		-- if the function is straight local, we need to create
		-- a scope for it so it can call itself.

		local inject_locals		= nil
		local statement_scope 		= self
		local name 			= assert(statement:tags("name"))

		if name:roles('local-variable-declaration') then

			--print("local-variable-declaration")

			-- function defined in local scope

			statement_scope 	= ScopeContext {
				parent 		= self
			}

			statement_scope:define_variable(name)

			statement_scope:create_reference(name, {
				direction 	= "write";
			})

		elseif name:roles("member-function-declaration") then
			local is_method		= name:roles("method-function-declaration")
			local considered 	= name
			local names 		= {}

			while not considered:roles("variable-reference") do
				assert(considered:roles("index-construct"))
				table.insert(names, 1, assert(considered:tags("index")))
				considered = assert(considered:tags("target"))
			end

			statement_scope:create_reference(considered,  {
				direction 	= "read";
			})

			if is_method then
				inject_locals = {
					{ name = "self", category = "parameter" }
				}
			end

		elseif name:roles("function-declaration") then
			-- function defined in global scope

			--print("function-declaration")

			local declared_globals = assert(statement:tags('declared_globals'))
			assert(#declared_globals == 1)
			local declared_global = declared_globals[1]

			statement_scope:create_reference(declared_global,  {
				direction = "write";
			})
		else
			error("UNKNOWN FUNCTION NAME ROLE: " .. name:name())
		end

		statement_scope:analyze_function_body(assert(statement:tags('body')), inject_locals)

		return statement_scope
	end

	function ScopeContext:analyze_statement_blocks(blocks, block_locals, inject_locals)
		local block_parent_scope = self

		if block_locals or inject_locals then
			block_parent_scope = ScopeContext {
				parent = self;
			}

			if block_locals then
				for i, lvar in ipairs(block_locals ) do
					block_parent_scope:define_variable(assert(lvar:terminals()[1]))
				end
			end

			if inject_locals then
				for i, lvar in ipairs(inject_locals) do
					lvar.scope = self
					assert(not block_parent_scope:is_root())
					block_parent_scope:define_variable(Variable(lvar))
				end
			end
		end

		for i, block in ipairs(blocks) do
			local block_scope = ScopeContext {
				parent = block_parent_scope
			}

			block_scope:analyze_block(block)
		end
	end

	function ScopeContext:analyze_assignment(statement)
		-- expressions are evaluated in the pre-existing scope
		local values 		= self:analyze_expressions(assert(statement:tags('expressions')))

		local statement_scope 	= self
		local locals 		= assert(statement:tags('declared_locals'))

		if #locals > 0 then
			statement_scope 	= ScopeContext {
				parent 		= self
			}

			for i, name in ipairs(locals) do
				statement_scope:define_variable(name:child(1))
			end
		end

		local assigned 	= assert(statement:tags('assigned'));
		local targets 	= {}

		for i, lvalue in ipairs(assigned) do
			if lvalue:roles{ "variable-reference", "variable-declaration" } then
				targets[i] = statement_scope:create_reference(lvalue)
			else
				-- In this case, we must not be in a
				-- local assignment block, as all local
				-- declarations must have the
				-- variable-declaration role.

				-- Because of this, the statement scope
				-- should still be the current scope.

				assert(statement_scope==self)
				assert(lvalue:roles("lvalue-expression"))
				targets[i] = statement_scope:analyze_expression(lvalue)
			end
		end

		local direct 	= math.min(#values, #targets)
		local indirect	= #targets - direct

		for i = 1, direct do
			statement_scope:create_assignment(targets[i], values[i])
		end

		-- TODO: a representation of the concept of "the Nth value
		--	returned by the evaluation of the expression: E" is
		--	probably going to be required if we want the ability
		--	to infer things about values returned by functions.
		--
		-- NOTE: The Value type tracks if a value is "expandable," and
		--	that flag is, at time of writing, correctly set by
		--	invocations and the varargs literal. That information
		--	can be used here to, at the very least, determine if
		--	it is even possible for the entire targets list to
		-- 	receive values.
		--
		-- print(string.format("%d values assigned to %d locations", #values, #targets))

		return statement_scope
	end

	--- Analyze a statement.
	---
	--- If the analyzed statement creates a new scope for the
	--- statements that follow it, this function should return
	--- that scope. The analze_statements function will use the
	--- returned scope as the parent scope for subsequent
	--- statements,
	function ScopeContext:analyze_statement(statement)
		if statement:roles('function-declaration') then
			return self:analyze_function_statement(statement)
		elseif statement:roles({ 'assignment-statement', 'variable-declaration'}) then
			return self:analyze_assignment(statement)
		end

		-- Since we are not a function statement, the tags
		-- 'expressions' and  'blocks' should be defined.

		local expressions 		= assert(statement:tags("expressions"))
		local blocks			= assert(statement:tags("blocks"))

		-- block locals may be defined as well

		local block_locals		= statement:tags("block_locals")

		-- first, we analyze the expressions
		self:analyze_expressions(expressions);
		self:analyze_statement_blocks(blocks, block_locals);
	end

	--- Analyze a list of statements that make up a scope.
	---
	--- The statements may be the entire contents of a block, but
	--- they may also be the statments that come *after* a local
	--- assignment statement, as that local assignment statement
	--- constitutes the beginning of a new effective scope.
	function ScopeContext:analyze_statements(statements)
		for i, statement in ipairs(statements) do
			local next_scope = self:analyze_statement(statement) or self

			if next_scope ~= self then
				next_scope:analyze_statements(table.slice(statements, i + 1))
				break
			elseif statement:roles('local-declaration') then
				error("internal error: statement that should create an inline scope failed to do so")
			end -- if inline
		end -- for
	end

	function ScopeContext:analyze_block(block)
		self:analyze_statements(block:tags("combined"))
	end

end
