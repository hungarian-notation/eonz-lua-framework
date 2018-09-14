local eonz 		= require 'eonz'
local support 		= require 'eonz.reflect.analysis.scope.support'
local Value 		= require 'eonz.reflect.analysis.value'
local ValueReference 	= require 'eonz.reflect.analysis.value_reference'

local InvocationReference = eonz.class { name = "eonz::reflect::InvocationReference", extends = ValueReference }
do
	function InvocationReference:init(opt)
		opt.token 	= opt.token or opt.identifier
		opt.expandable 	= true;
		opt.dynamic	= true;
		InvocationReference:__super { self, opt }
		self._args 	= assert(opt.arguments)
	end

	function InvocationReference:arguments()
		return self._args
	end

	function InvocationReference:arguments_string()
		local bf = eonz.string.builder()

		for i, arg in ipairs(self:arguments()) do
			if i ~= 1 then
				bf:append(", ");
			end
			bf:append(arg:display())
		end

		return tostring(bf)
	end

	function InvocationReference:display()
		return "(" .. self:object():display() .. ")(" .. self:arguments_string() .. ")"
	end

	InvocationReference.__tostring = InvocationReference.display
end

return InvocationReference
