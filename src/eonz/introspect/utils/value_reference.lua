local eonz 	= require 'eonz'
local support 	= require 'eonz.introspect.utils.scope.support'
local Value 	= require 'eonz.introspect.utils.value'

local ValueReference = eonz.class { name = "eonz::introspect::ValueReference", extends = Value }
do
	function ValueReference:init(opt)
		ValueReference:__super { self, opt }

		self._scope	= assert(opt.scope)
		self._what 	= assert(opt.object or opt.what or opt.target)

		self:register()
	end

	function ValueReference:register()
		self:object():add_reference(self)
	end

	-- Used to delete a reference when it is superseded by a more
	-- specific interaction.
	function ValueReference:delete()
		self:object():remove_reference(self)
	end

	function ValueReference:object()
		return self._what
	end

	function ValueReference:display()
		return self:object():display()
	end

	ValueReference.__tostring = ValueReference.display
end

return ValueReference
