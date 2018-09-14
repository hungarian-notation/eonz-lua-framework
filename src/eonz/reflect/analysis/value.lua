local eonz = require 'eonz'
local table = eonz.pf.table


local Value = eonz.class "eonz::reflect::Value"
do

	--- Common initializer for all Values and Value interactions.
	---
	--- @param opt.scope
	---	The scope the value belongs to.
	--- @param opt.token @optional
	---	The token from the source that "defines" this value.
	function Value:init(opt)
		opt = opt or {}
		Value:__super { self, opt }

		self._references	= {}
		self._token		= opt.token
		self._syntax		= opt.syntax
		self._scope		= assert(opt.scope)

		self._dynamic		= not not opt.dynamic
		self._expandable	= not not opt.expandable
		self._static		= not not opt.static

		self._display		= opt.display
		self._tautological	= opt.tautological

		if self._static then
			self._static		= true
			self._type		= assert(opt.static_type)
			self._static_value	= opt.static_value
		else
			self._type		= opt.type or 'unknown'
		end

		self._scope:add_value(self)
	end

	function Value.make_dynamic(args)
		local DynamicValue		= require 'eonz.reflect.analysis.dynamic_value'

		return DynamicValue {
			scope 			= assert(args.scope);
			syntax 			= assert(args.syntax, "must provide syntax rule for dynamic value");
			type			= args.type;
			dynamic_category 	= args.dynamic_category or args.category;
		}
	end

	function Value.make_static(args)
		return Value {
			scope 		= assert(args.scope);
			syntax 		= assert(args.syntax, "must provide syntax rule for static value");
			static		= true;

			-- If we're creating this from a constexpr syntax
			-- element, we can use the tags from the parser

			static_type	= args.syntax:roles('constexpr') and args.syntax:tags('constexpr')
						or args.static_type or args.type;
			static_value 	= not args.syntax:roles('constexpr') and args.static_value or args.syntax:tags('value') ;

			tautological	= not not args.tautological;
		}
	end

	function Value:is_expandable()
		return self._expandable
	end

	function Value:is_static()
		return self._static
	end

	function Value:value_type()
		return self._type
	end

	function Value:known_type()
		return self:value_type() ~= 'unknown' and self:value_type()
	end

	function Value:static_value()
		return assert(self:is_static(), 'value is not static') and self._static_value
	end

	function Value:is_tautology()
		return self._tautological;
	end

	function Value:is_dynamic()
		return self._dynamic
	end

	function Value:scope()
		return self._scope
	end

	function Value:add_reference(reference)
		if not table.contains(self._references, reference) then
			table.insert(self._references, reference)
		end
	end

	function Value:remove_reference(reference)
		local position = table.index_of(self._references, reference)

		if position then
			assert(rawequal(table.remove(self._references, position), reference))
		end
	end

	--- Returns a list of interactions that were found to act on this value.
	---
	--- This may not be a complete listing,
	function Value:references(where_predicate)
		if not where_predicate then
			return self._references
		else
			if type(where_predicate) == 'table' then
				where_predicate = assert(where_predicate[1])
			end

			assert(type(where_predicate) == 'function')

			local matched = {}

			for i, reference in ipairs(self._references) do
				if where_predicate(reference) then
					matched[#matched + 1] = reference
				end
			end

			return matched
		end
	end

	--- The token that defines this value. This is present only if then
	--- value was initialized with a `token` parameter.
	function Value:token()
		return self._token
	end

	function Value:syntax()
		return self._syntax
	end

	function Value:display()
		return self._display
			or self:is_tautology() 	and "«tautology»"
			or self:is_static() and "«static " .. self:value_type() .. "»"
			or self:token() and "token: " .. tostring(self:token())
			or self:syntax() and "syntax: " .. tostring(self:syntax())
			or error("no representation for value of type: " .. tostring(eonz.get_class(self)))
	end

	function Value:__tostring()
		return self:display()
	end
end

return Value
