local eonz 	= require 'eonz'
local support 	= require 'eonz.reflect.utils.scope.support'

return function (utils)

	local Value 			= require 'eonz.reflect.utils.value'
	local ValueReference 		= require 'eonz.reflect.utils.value_reference'

	local IndexingReference	 	= require 'eonz.reflect.utils.indexing_reference'
	local InvocationReference 	= require 'eonz.reflect.utils.invocation_reference'
	local Variable 			= require 'eonz.reflect.utils.variable'
	local Assignment		= require 'eonz.reflect.utils.assignment'

	local ScopeContext = eonz.class "eonz::reflect::ScopeContext"
	do
		require("eonz.reflect.utils.scope.analyzers")(ScopeContext)

		function ScopeContext:init(opt)
			if opt.root then
				self._parent 	= false
				self._root	= true
			else
				self._parent	= assert(opt.parent, "must provide root=true or parent=<parent-context>")
				self._root	= false
			end

			self._locals 		= {}
			self._references	= {}
			self._children		= {}

			-- Tracks all values that were evaluated in this
			-- scope.
			self._values		= {}

			if self._parent then
				table.insert(self._parent._children, self)
			end
		end

		function ScopeContext:add_value(value)
			eonz.table.insert(self._values, value)
		end

		function ScopeContext:values()
			return self._values;
		end

		function ScopeContext:parent()
			local parent = self._parent
			return parent
		end

		function ScopeContext:children()
			return self._children
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

		function ScopeContext:global_variables()
			return self:get_root():scope_variables()
		end

		function ScopeContext:define_variable(token)
			local variable


			if eonz.get_class(token) == Variable then
				variable = token
			else
				local actual_token = type(token) ~= 'string' 	and support.get_identifier_token(token) or nil;

				variable = Variable {
					scope 		= self;
					name 		= type(token) == 'string' 	and token or nil;
					identifier	= actual_token;
					token		= actual_token;
				}
			end


			table.insert(self:scope_variables(), variable)

			return variable
		end

		function ScopeContext:resolve_variable(name, token)

			for i, var in ipairs(self:scope_variables()) do
				if (var:name() == name) then
					return var, self:depth()
				end
			end

			if self:parent() then
				return self:parent():resolve_variable(name, token)
			else
				return self:define_variable(token or name), self:depth()
			end
		end

		function ScopeContext:record_reference(reference)
			table.insert(self._references, reference)
		end

		function ScopeContext:create_reference(to)
			local args 			= { scope = self }

			if eonz.lexer.SyntaxNode:is_instance(to) then
				args.syntax 		= to
			end

			args.token 			= support.get_identifier_token(to:tags('name'))--:child(1)
			local name 			= args.token:text()
			local resolved, resolved_depth 	= self:resolve_variable(name, args.token)

			args.object 			= assert(resolved, "resolved was nil for: " .. tostring(to))
			local reference 		= ValueReference (args)

			self:record_reference(reference)
			return reference
		end

		function ScopeContext:create_assignment(target, assignment_value)
			local value_reference = nil

			if target:get_class() == ValueReference then
				-- supersede plain ValueReference instances

				value_reference = target
				target = value_reference:object()
			end

			local reference = Assignment {
				scope			= self;
				target			= assert(target);
				assigned_value		= assignment_value
			}

			if value_reference then
				-- if this index is superseding a ValueReference
				-- then clean up that ValueReference's registration
				-- in the Variable record.

				value_reference:delete()
			end

			self:record_reference(reference)

			return reference;
		end


		function ScopeContext:create_invocation(value, args)
			local value_reference = nil

			if value:get_class() == ValueReference then
				-- supersede plain ValueReference instances
				value_reference = value
				value = value_reference:object()
			end

			local reference = InvocationReference {
				scope		= self;
				target		= assert(value);
				token		= args.token or nil;
				syntax		= args.syntax;
				arguments	= args.arguments
			}

			if value_reference then
				-- if this index is superseding a ValueReference
				-- then clean up that ValueReference's registration
				-- in the Variable record.
				value_reference:delete()
			end

			self:record_reference(reference)

			return reference;
		end

		function ScopeContext:create_index_reference(value, args)
			local value_reference = nil

			if value:get_class() == ValueReference then
				-- supersede plain ValueReference instances
				value_reference = value
				value = value_reference:object()
			end

			local reference = IndexingReference {
				scope		= self;
				target 		= value;
				index 		= args.value;
				index_type	= args.type;
				identifier	= args.identifier;
				method		= assert(type(args.method) == 'boolean') and args.method
			}

			if value_reference then
				-- if this index is superseding a ValueReference
				-- then clean up that ValueReference's registration
				-- in the Variable record.
				value_reference:delete()
			end

			self:record_reference(reference)

			return reference;
		end
	end

	function utils.analyze(chunk)
		local chunk_scope	= ScopeContext {
			root = true
		}

		local block = chunk:select { first = 'block-construct' }

		chunk_scope:analyze_block(block)

		return chunk_scope
	end
end
