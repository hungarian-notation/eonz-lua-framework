local eonz 	= require 'eonz'
local support 	= require 'eonz.reflect.analysis.scope.support'

return function (utils)

	local Value 			= require 'eonz.reflect.analysis.value'
	local ValueReference 		= require 'eonz.reflect.analysis.value_reference'

	local IndexingReference	 	= require 'eonz.reflect.analysis.indexing_reference'
	local InvocationReference 	= require 'eonz.reflect.analysis.invocation_reference'
	local Variable 			= require 'eonz.reflect.analysis.variable'
	local Assignment		= require 'eonz.reflect.analysis.assignment'

	local ScopeContext = eonz.class "eonz::reflect::ScopeContext"
	do
		require("eonz.reflect.analysis.scope.analyzers")(ScopeContext)
		require("eonz.reflect.analysis.scope.value_factories")(ScopeContext)


		function ScopeContext:init(opt)

			if opt.root then
				self._parent 	= false
				self._root	= true
			else
				self._parent	= assert(opt.parent, "must provide root=true or parent=<parent-context>")
				self._root	= false
			end

			if type(opt.closure) == 'boolean' then
				self._closure = opt.closure and self or nil
			elseif type(opt.closure) == 'nil' then
				self._closure = nil
			else assert(opt.closure:get_class() == ScopeContext)
				self._closure = opt.closure
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

		--- Returns the scope that highest closure that this scope is
		--- part of. If this scope is a closure, this function will
		--- return a reference to this scope.
		---
		--- This function never returns nil, as the root scope is a
		--- closure.
		function ScopeContext:closure()
			return 	self._closure
				or (self:is_root() and self)
				or (self:parent():closure())
		end

		function ScopeContext:is_closure()
			return self._closure == self
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

		function ScopeContext:define_variable(token, args)
			args = args or {}

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
					category	= args.category;
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
	end

	function utils.analyze(opt)

		if type(opt) == 'string' then
			opt = eonz.lexer.Source {
				path = opt;
			}
		end

		if type(opt) == 'table' and not eonz.get_class(opt) then
			if type(opt.path) == 'string' then
				opt = eonz.lexer.Source {
					path = opt;
				}
			end

			if eonz.get_class(opt.source) == eonz.lexer.Source then
				opt = opt.source
			end
		end

		if eonz.get_class(opt) == eonz.lexer.Source then
			opt = eonz.reflect.LuaParser { source = opt } :chunk()
		end

		if eonz.get_class(opt) == eonz.lexer.SyntaxNode then
			opt = { ast = opt };
		end

		local chunk = assert(eonz.get_class(opt.ast) == eonz.lexer.SyntaxNode and opt.ast, "could not derive AST from options")

		local chunk_scope	= ScopeContext {
			root = true
		}

		local block = chunk:select { first = 'block-construct' }

		chunk_scope:analyze_block(block)

		return chunk_scope, chunk
	end
end
