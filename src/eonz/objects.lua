-- NOTE: This module is a dependency of `eonz.platform` and will be loaded
-- before the cross-platform path system is initialized. It must be entirely
-- platform agnostic.

local objects = {}

local CONSTRUCTOR_CACHE_KEY 	= "__type_constructor__"

local CLASS_FIELD__SUPER	= "__super"
local CLASS_FIELD__NAME		= "__class_name"
local CLASS_FIELD__CLASS	= "__class"

local CONSTRUCTOR_NAMES		= { 'new', 	'__new'  }
local INITIALIZER_NAMES		= { 'init', 	'__init' }

local BaseObject 	= {}
do 	BaseObject.__index = BaseObject
	BaseObject[CLASS_FIELD__NAME] 	= "eonz::BaseObject"
	BaseObject[CLASS_FIELD__SUPER] 	= nil
	BaseObject[CLASS_FIELD__CLASS]	= BaseObject

	function BaseObject.resolve_own(T, keys)
		if type(keys) == 'string' then
			keys = { keys }
		end

		for i, key in ipairs(keys) do
			local found = rawget(T, key)

			if found then
				return found
			end
		end

		return nil
	end

	function BaseObject.resolve(T, keys, default_provider)
		if type(keys) == 'string' then
			keys = { keys }
		end

		if rawequal(T, BaseObject) then
			return default_provider and default_provider(T) or nil
		else
			local own = BaseObject.resolve_own(T, keys)

			if own then
				return own, T
			else
				return BaseObject.resolve(rawget(T, CLASS_FIELD__SUPER), keys, default_provider)
			end
		end
	end

	local function default_constructor(T)
		local init = BaseObject.resolve(T, INITIALIZER_NAMES, nil)

		if type(init) == 'function' then
			return function(...)
				local instance = setmetatable({}, T)
				init(instance, ...)
				return instance
			end
		else
			return function()
				return function(...)
					return setmetatable({}, T)
				end
			end
		end
	end

	function BaseObject.construct_instance(T, ...)
		local constructor = rawget(T, CONSTRUCTOR_CACHE_KEY)

		if not constructor then
			local source
			constructor, source = BaseObject.resolve(T, CONSTRUCTOR_NAMES)

			if constructor and not rawequal(source, T) then
				--[[
					When a type uses an explicit constructor,
					every child type must also use an explicit
					constructor as well, as the metatable
					for the instance is set in the constructor.

					For this reason, initializers should be
					preferred over constructors.
				--]]

				error("type "
					.. BaseObject.type_name(T)
					.. " must override constructor defined in "
					.. BaseObject.type_name(source))
			end

			constructor = constructor or default_constructor(T)
			rawset(T, CONSTRUCTOR_CACHE_KEY, constructor)
		end

		return constructor(...)
	end

	function BaseObject.is_class(T)
		return type(T) == 'table' and rawequal(BaseObject, T) or not not rawget(T, CLASS_FIELD__CLASS)
	end

	function BaseObject.super(T)
		T = BaseObject.get_class(T)

		if not T or rawequal(BaseObject, T) then
			return nil
		else
			return assert(rawget(T, CLASS_FIELD__SUPER))
		end
	end

	function BaseObject.get_class(T)
		return type(T) == 'table' and
			((rawget(T, CLASS_FIELD__CLASS))
				or (getmetatable(T) and BaseObject.get_class(getmetatable(T)))
				or nil) or nil
	end

	function BaseObject.type_name(T)
		return BaseObject.resolve_own(BaseObject.get_class(T), CLASS_FIELD__NAME)
	end

	function BaseObject.assignable_from(T, U)
		T = BaseObject.get_class(T)
		U = BaseObject.get_class(U)

		if T == nil or U == nil then
			return false
		else
			while U do
				if T:is_instance(U) then
					return true
				else
					U = U:super()
				end
			end

			return false
		end
	end

	function BaseObject.is_instance(T, U)
		T = BaseObject.get_class(T)
		U = BaseObject.get_class(U)
		return T and rawequal(T, U)
	end

	BaseObject.__call = BaseObject.construct_instance
end

objects.BaseObject = BaseObject

function objects.class(opt)
	if type(opt) == 'string' then
		opt = { name=opt }
	end

	opt = require('eonz.options').from(opt, {
		extends = objects.BaseObject
	})

	local class = {}

	class.__index 			= class
	class.__call			= BaseObject.construct_instance
	class[CLASS_FIELD__CLASS]	= class
	class[CLASS_FIELD__NAME]	= opt.name
	class[CLASS_FIELD__SUPER]	= opt.extends

	return setmetatable(class, opt.extends)
end

return objects
