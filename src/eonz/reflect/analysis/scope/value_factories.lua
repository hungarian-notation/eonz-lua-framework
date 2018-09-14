return function(ScopeContext)
	local eonz 			= require 'eonz'
	local table			= eonz.pf.table;

	local support 			= require 'eonz.reflect.analysis.scope.support'
	local Value 			= require 'eonz.reflect.analysis.value'
	local DynamicValue		= require 'eonz.reflect.analysis.dynamic_value'
	local ValueReference 		= require 'eonz.reflect.analysis.value_reference'
	local IndexingReference	 	= require 'eonz.reflect.analysis.indexing_reference'
	local InvocationReference 	= require 'eonz.reflect.analysis.invocation_reference'
	local Variable 			= require 'eonz.reflect.analysis.variable'
	local Assignment		= require 'eonz.reflect.analysis.assignment'

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
