local eonz 	= require "eonz"
local support 	= require "eonz.introspect.utils.scope.support"

return function (utils)

	local Value = eonz.class "eonz::introspect::Value"
	do
		function Value:init(opt)
			self._interactions	= {}
		end

		function Value:add_interaction(interaction)
			table.insert(self._interactions, interaction)
		end

		function Value:interactions()
			return self._interactions
		end
	end

	local ValueInteraction = eonz.class { name = "eonz::introspect::Variable", extends = Value }
	do
		ValueInteraction.REFERENCED 	= "reference-interaction"
		ValueInteraction.ASSIGNED	= "assignment-interaction"
		ValueInteraction.INDEXED	= "indexed-interaction"

		function ValueInteraction:init(opt)
			self:__super(opt)
			self._scope		= assert(opt.scope)
			self._what		= assert(opt.object or opt.what or opt.target)
			self._method 		= assert(opt.method)
			self._index		= opt.index
			self._index_type	= opt.index_type
			self._type		= opt.type
			self._what:add_interaction(self)
		end

		function ValueInteraction:object()
			return self._what
		end

		function ValueInteraction:method()
			return self._method
		end

		function ValueInteraction:index()
			return self._index
		end

		function ValueInteraction:index_type()
			return self._index_type
		end

		function ValueInteraction:type()
			return self._type
		end

		function ValueInteraction:name()
			local index_string = ""
			local method_string = " " .. self:method()

			if self:index() then
				local surround = self:index_type() == 'string' and "\"" or ""
				index_string = "[" .. surround .. tostring(self:index()) .. surround .. "]"
				method_string = ""
			end

			return "<" .. tostring(self:object()) .. method_string  .. index_string .. ">"
		end

		ValueInteraction.__tostring = ValueInteraction.name
	end

	local Variable = eonz.class { "eonz::introspect::Variable", extends = Value }
	do
		function Variable:init(opt)
			self:__super(opt)
			self._scope		= assert(opt.scope)
			self._category		= opt.category
			self._name		= opt.name
			self._identifier 	= opt.identifier

			assert(opt.name or opt.identifier)

			local effective_name = opt.name or opt.identifier and opt.identifier:text();

			self._value		= Value {
				name 		= effective_name;
				identifier	= opt.identifier;
			}
		end

		function Variable:identifier()
			return self._identifier
		end

		function Variable:category()
			return self._category or self:is_global() and "global" or "local"
		end

		function Variable:__tostring()
			return "<" .. self:category() .. ":" .. self:name() .. ">"
		end

		function Variable:is_global()
			return self:scope():is_root()
		end

		function Variable:is_local()
			return not self:is_global()
		end

		function Variable:scope()
			return self._scope
		end

		function Variable:name()
			return self._name or self:identifier():text()
		end
	end

	local ScopeContext = eonz.class "eonz::introspect::ScopeContext"
	do
		function ScopeContext:init(opt)
			if opt.root then
				self._parent 	= false
				self._root	= true
			else
				self._parent	= assert(opt.parent, "must provide root=true or parent=<parent-context")
				self._root	= false
			end

			self._locals 		= {}
			self._interactions	= {}
			self._children		= {}

			if self._parent then
				table.insert(self._parent._children, self)
			end
		end

		function ScopeContext:log_raw(message)
			io.write(tostring(message))
		end

		function ScopeContext:log(message)
			self:log_raw(string.rep("│   ", self:depth()) .. tostring(message) .. "\n")
		end

		function ScopeContext:parent()
			return self._parent
		end

		function ScopeContext:is_root()
			return not self:parent()
		end

		function ScopeContext:get_root()
			return self:is_root() and self or self:parent():get_root()
		end

		function ScopeContext:depth()
			return self:parent() and (self:parent():depth() + 1) or 0
		end

		function ScopeContext:scope_variables()
			return self._locals
		end

		local DECLARE_ARROW 		= "◀▬▬▬▬▬▬▬"
		local READ_REFERENCE_ARROW 	= "▬▬▬▬▬▬▬▶"
		local WRITE_REFERENCE_ARROW 	= "▬▬▬▶◀▬▬▬"
		local READ_GLOBAL_ARROW 	= "▬▬[G]▬▬▶"
		local WRITE_GLOBAL_ARROW 	= "◀▬▬[G]▬▬"

		function ScopeContext:define_variable(token)
			local variable

			if eonz.get_class(token) == Variable then
				variable = token
			else
				variable = Variable {
					scope 		= self;
					name 		= type(token) == 'string' 	and token or nil;
					identifier	= type(token) ~= 'string' 	and support.get_identifier_token(token) or nil;
				}
			end

			if not self:is_root() then
				self:log("╭─ " .. DECLARE_ARROW .. " " .. variable:name())
			end

			table.insert(self:scope_variables(), variable)

			return variable
		end

		function ScopeContext:resolve_variable(name)
			for i, var in ipairs(self:scope_variables()) do
				if (var:name() == name) then
					return var, self:depth()
				end
			end

			if self:parent() then
				return self:parent():resolve_variable(name)
			else
				return self:define_variable(name), self:depth()
			end
		end

		function ScopeContext:log_reference(to, token, name, resolved, resolved_depth, direction)
			local interface_arrow = direction == 'read' and READ_REFERENCE_ARROW or WRITE_REFERENCE_ARROW

			if resolved:is_local() then
				for i = 0, self:depth() - 1 do
					if i < resolved_depth then
						self:log_raw("│   ")
					elseif i == resolved_depth then
						self:log_raw("╰───")
					else
						self:log_raw("────")
					end
				end

				local start_tag = (self:depth() == resolved_depth) and "╰─" or "┼─"
				self:log_raw(start_tag .. " " .. interface_arrow .. " " .. name .. "\n")
			else
				interface_arrow = direction == 'read' and READ_GLOBAL_ARROW or WRITE_GLOBAL_ARROW

				for i = 0, self:depth() - 1 do
					self:log_raw("│   ")
				end

				self:log_raw("◯  " .. interface_arrow .. " " .. name .. " \n")


			end
		end

		function ScopeContext:record_interaction(interaction)
			table.insert(self._interactions, interaction)
		end

		function ScopeContext:create_reference_interaction(to, info)
			local token 			= support.get_identifier_token(to:tags('name'))--:child(1)
			local name 			= token:text()
			local resolved, resolved_depth 	= self:resolve_variable(name)

			assert(resolved, "resolved was nil for: " .. tostring(to))

			local method 	= nil

			if info.direction == 'write' then
				method = ValueInteraction.ASSIGNED
			elseif info.direction == 'read' then
				method = ValueInteraction.REFERENCED
			end

			self:log_reference(to, token, name, resolved, resolved_depth, assert(info.direction))

			local interaction = ValueInteraction {
				scope	= self;
				object	= assert(resolved);
				method	= assert(method);
			}

			self:record_interaction(interaction)

			return interaction
		end

		local function is_scope_statement(node)
			return node:roles {
				"local-function-declaration-statement";
				"function-declaration-statement";
				"do-statement";
				"if-statement";
				"for-range-statement";
				"for-iterator-statement";
				"while-statement";
				"repeat-statement";
			}
		end

		function ScopeContext:analyze_block(block)
			self:analyze_statements(block:tags("combined"))
		end

		function ScopeContext:create_index_interaction(value, args)
			local interaction = ValueInteraction {
				scope		= self;
				target 		= value;
				method 		= ValueInteraction.INDEXED;
				index 		= args.value;
				index_type	= args.type;
			}

			self:record_interaction(interaction)

			print(interaction)

			return interaction;
		end

		function ScopeContext:analyze_index_expression(expression)
			local target 	= assert(expression:tags('target'))
			local index 	= assert(expression:tags('index'))

			if expression:roles('identifier-index-expression') then
				local target_value = self:analyze_expression(target)
				if target_value then
					return self:create_index_interaction(target_value, {
						value	= support.get_identifier_token(index):text();
						type	= 'string';
					})
				end
			elseif expression:roles('value-index-expression') then
				if index:tags('constexpr') then
					-- we can continue static analysis
					local target_value = self:analyze_expression(target)
					if target_value then
						return self:create_index_interaction(target_value, {
							value	= index:tags('value');
							type	= index:tags('constexpr');
						})
					end
				else
					-- dynamic index
					self:analyze_expression(index)
					self:analyze_expression(target)
				end
			end

		end

		function ScopeContext:analyze_expression(expression)
			assert(expression:roles("expression"), "not an expression: " .. tostring(expression))

			self:log("┆  " .. expression:name())

			if expression:roles
			{
				'string-literal';
				'number-literal';
				'boolean-literal';
				'nil-literal';
				'varargs-literal';
			}
			then
				-- nothing to do here
			elseif (expression:roles('function-literal')) then
				return self:analyze_function_body(expression:rules()[1])
			elseif (expression:roles('variable-reference')) then
				return self:create_reference_interaction(expression, {
					direction = "read"
				})
			elseif (expression:roles('control-flow-condition')) then
				-- TODO: wrapped-expression role?
				return self:analyze_expression(assert(#expression:children() == 1 and expression:child(1)))
			elseif (expression:roles {
				'value-index-expression';
				'identifier-index-expression';
			}) then
				return self:analyze_index_expression(expression)
			elseif (expression:roles({
				'atomic-expression';
				'operation-expression';
				'table-expression';
				'invocation-expression';
			})) then
				self:analyze_expressions(assert(expression:tags("expressions")))
			else
				self:log("! !!!")
				self:log("! !!!")
				self:log("! !!!")
				self:log(":  " .. "UNKNOWN EXPRESSION: " .. expression:name())
				self:log("! !!!")
				self:log("! !!!")
				self:log("! !!!")
			end
		end

		function ScopeContext:analyze_expressions(expressions)
			for i, exp in ipairs(expressions) do
				self:analyze_expression(exp)
			end
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
			self:log(statement:name() .. " (function declaration)")

			-- if the function is straight local, we need to create
			-- a scope for it so it can call itself.

			local inject_locals		= nil
			local statement_scope 		= self
			local name 			= assert(statement:tags("name"))

			if name:roles('local-variable-declaration') then

				-- function defined in local scope

				statement_scope 	= ScopeContext {
					parent 		= self
				}

				statement_scope:define_variable(name)

				statement_scope:create_reference_interaction(name, {
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

				statement_scope:create_reference_interaction(considered,  {
					direction 	= "read";
				})

				if is_method then
					inject_locals = {
						{ name = "self", category = "parameter" }
					}
				end

			elseif name:roles("function-declaration") then
				-- function defined in global scope

				local declared_globals = assert(statement:tags('declared_globals'))
				assert(#declared_globals == 1)
				local declared_global = declared_globals[1]

				statement_scope:create_reference_interaction(declared_global,  {
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

			if block_locals and #block_locals > 0 then
				block_parent_scope = ScopeContext {
					parent = self;
				}

				for i, lvar in ipairs(block_locals) do
					block_parent_scope:define_variable(assert(lvar:terminals()[1]))
				end

				if inject_locals then
					for i, lvar in ipairs(inject_locals) do
						lvar.scope = self
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
			self:log(statement:name() .. " (assignment)")

			-- expressions are evaluated in the pre-existing scope
			self:analyze_expressions(assert(statement:tags('expressions')))

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

			local assigned = assert(statement:tags('assigned'));

			for i, lvalue in ipairs(assigned) do
				if lvalue:roles{ "variable-reference", "variable-declaration" } then
					statement_scope:create_reference_interaction(lvalue, {
						direction 	= "write";
					})
				else
					-- In this case, we must not be in a
					-- local assignment block, as all local
					-- declarations must have the
					-- variable-declaration role.

					-- Because of this, the statement scope
					-- should still be the current scope.

					assert(statement_scope==self)

					assert(lvalue:roles("lvalue-expression"))
					statement_scope:analyze_expression(lvalue)
				end
			end

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

			self:log(statement:name() .. " (general)")

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
	end

	function utils.analyze_references(node, opt)
		local chunk_scope	= ScopeContext {
			root = true
		}
		local block = node:select { first = 'block-construct' }
		chunk_scope:analyze_block(block)
	end
end
