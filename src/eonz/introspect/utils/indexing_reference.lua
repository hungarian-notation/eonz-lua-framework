local eonz 		= require "eonz"
local support 		= require "eonz.introspect.utils.scope.support"
local Value 		= require "eonz.introspect.utils.value"
local ValueReference 	= require "eonz.introspect.utils.value_reference"

local IndexingReference = eonz.class { name = "eonz::introspect::IndexingReference", extends = ValueReference }
do
	function IndexingReference:init(opt)
		opt.token = opt.token or opt.identifier

		IndexingReference:__super { self, opt }

		self._index		= opt.index
		self._index_type	= opt.index_type
		self._method		= assert(type(opt.method) == 'boolean') and opt.method
	end

	function IndexingReference:index()
		return self._index
	end

	function IndexingReference:index_type()
		return self._index_type
	end

	function IndexingReference:identifier()
		return self:token()
	end

	function IndexingReference:is_method()
		return self._method
	end

	function IndexingReference:display()
		local valid_identifier = self:index_type() == 'string' and
			tostring(self:index_type()):match("^[a-zA-Z_][a-zA-Z0-9_]*$")

		if self:identifier() or valid_identifier then
			return self:object():display() .. (self:is_method() and " -> :" or " -> ") .. self:index()
		elseif self:index_type() == 'string' then
			return self:object():display() .. " -> [\"" .. self:index() .. "\"]"
		else
			return self:object():display() .. " -> [" .. self:index() .. "]"
		end
	end

	IndexingReference.__tostring = IndexingReference.name
end

return IndexingReference
