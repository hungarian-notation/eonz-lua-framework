local eonz 		= require 'eonz'

local support 		= require 'eonz.reflect.analysis.scope.support'
local Value 		= require 'eonz.reflect.analysis.value'

local Variable = eonz.class { name = "eonz::reflect::Variable", extends = Value }
do
	function Variable:init(opt)
		opt.token 				= opt.token or opt.identifier
		Variable:__super { self, opt }

		self._argument				= not not opt.argument
		self._category				= opt.category
		self._name				= opt.name
		self._identifier 			= opt.identifier

		assert(opt.name or opt.identifier)
		local effective_name 			= opt.name or opt.identifier and opt.identifier:text();
	end

	function Variable:identifier()
		return self._identifier
	end

	function Variable:category()
		return self._category or (self:is_global() and "global" or "local")
	end

	function Variable:is_global()
		return assert(assert(self, 'self was nil').scope and self:scope(), "self.scope was nil"):is_root()
	end

	function Variable:is_local()
		return not self:is_global()
	end

	function Variable:name()
		return  (self._name or self:identifier():text())
	end

	local _Assignment = nil

	local function lazy_Assignment()
		if not _Assignment then
			_Assignment = require('eonz.reflect.analysis.assignment')
		end

		return _Assignment
	end

	function Variable:assignments(predicate)
		if type(predicate) == 'table' then
			predicate = assert(predicate[1])
		end

		return self:references {
			function (ref)
				return ref:get_class() == lazy_Assignment()
					and ((not predicate) or (predicate(ref)))
			end
		}
	end

	--- Gets a list of assignments that originate from a closure that
	--- is not the closure this variable was defined in.
	---
	--- The existence of foreign assignments makes it hard to reason about
	--- the contents of this variable between statements.
	function Variable:foreign_assignments()
		local home_closure = self:scope():closure()

		return self:assignments {
			function (ref)
				return ref:scope():closure() ~= home_closure
			end
		}
	end

	function Variable:display()
		return  (self:is_global() and "_G -> " or "")
			.. self:name()

		-- caret indicates that this variable is captured as an upvalue
		-- of a closure and that the variable is written to from that
		-- closure.
			.. (#self:foreign_assignments() > 0 and "^" or "")
	end

	function Variable:__tostring()
		return (self:is_global() and "[global] " or "[local] ") .. self:display()
	end
end

return Variable
