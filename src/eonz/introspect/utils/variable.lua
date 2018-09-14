local eonz 		= require 'eonz'
local support 		= require 'eonz.introspect.utils.scope.support'
local Value 		= require 'eonz.introspect.utils.value'

local Variable = eonz.class { name = "eonz::introspect::Variable", extends = Value }
do
	function Variable:init(opt)
		opt.token 				= opt.token or opt.identifier
		Variable:__super { self, opt }
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

	function Variable:display()
		return  (self:is_global() and "_G -> " or "") .. self:name()
	end

	function Variable:__tostring()
		return (self:is_global() and "[global] " or "[local] ") .. self:display()
	end
end

return Variable
