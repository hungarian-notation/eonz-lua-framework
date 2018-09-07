-- NOTE: This module is a dependency of `eonz.platform` and will be loaded
-- before the cross-platform path system is initialized. It must be entirely
-- platform agnostic.

local objects = {}

local CONSTRUCTOR_CACHE_KEY 	= "__type_constructor__"

local CLASS_FIELD__SUPER	= "__class_super"
local CLASS_FIELD__NAME		= "__class_name"
local CLASS_FIELD__CLASS	= "__class"

local CONSTRUCTOR_NAMES		= { '__new' ,	'__constructor', 'new'	}
local INITIALIZER_NAMES		= { '__init', 	'__initialize', '__initializer', 'init'	}
local METHOD_NAME_SETS		= { CONSTRUCTOR_NAMES, INITIALIZER_NAMES }

local table_contains		= require 'eonz.polyfill.detail.contains'

local BaseObject 	= {}
do 	BaseObject.__index = BaseObject
	BaseObject[CLASS_FIELD__NAME] 	= "eonz::BaseObject"
	BaseObject[CLASS_FIELD__SUPER] 	= nil
	BaseObject[CLASS_FIELD__CLASS]	= BaseObject

	function BaseObject.__init() end

	function BaseObject.resolve_own(T, keys)
		if type(keys) == 'string' then
			keys = { keys }
		end

		if type(keys) ~= 'table' then
			error('bad argument #2, expected string or table of strings', 2)
		end

		for i, key in ipairs(keys) do
			if type(T) ~= 'table' then
				error('bad argument #1, expected table', 2)
			end

			if type(key) ~= 'string' then
				error('bad argument #2, expected string or table of strings', 2)
			end

			local found = rawget(T, key)

			if found then
				return found
			end
		end

		return nil
	end

	function BaseObject.resolve(T, keys, default_provider)
		if not T then
			return default_provider and default_provider(T) or nil
		elseif type(T) ~= 'table' then
			error('bad argument #1, expected table or nil', 2)
		end

		if type(keys) == 'string' then
			local set = nil

			for i, method in ipairs(METHOD_NAME_SETS) do
				if table_contains(method, keys) then
					set = method
				end
			end

			keys = set or { keys }
		end

		if type(keys) ~= 'table' then
			error('bad argument #2, expected string or table of strings', 2)
		end

		local resolved = BaseObject.resolve_own(T, keys)

		if resolved then
			return resolved, T
		else
			return BaseObject.resolve(rawget(T, CLASS_FIELD__SUPER), keys, default_provider)
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
		if not BaseObject.is_class(T) then
			error('bad argument #1, expected class table', 2)
		end

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

	function BaseObject.super(self, key)
		local T = BaseObject.get_class(self)

		local super

		if not T or rawequal(BaseObject, T) then
			super = nil
		else
			super = assert(rawget(T, CLASS_FIELD__SUPER))
		end

		local result = super

		if key then
			result = BaseObject.resolve(super, key, nil)
		end

		--print("super", self, tostring(super), key, tostring(result))

		return result
	end

	local table_unpack = _G['unpack'] or table.unpack

	function BaseObject.__super(object, ...)
		local key, argtable

		local args = {...}

		local ARGUMENT_ERROR = "expected (string, argtable) or (argtable)"

		if #args == 1 then
			key		= INITIALIZER_NAMES[1]
			argtable 	= assert(type(args[1]) == 'table'  and args[1], ARGUMENT_ERROR)
		elseif #args == 2 then
			key 		= assert(type(args[1]) == 'string' and args[1], ARGUMENT_ERROR)
			argtable 	= assert(type(args[2]) == 'table'  and args[2], ARGUMENT_ERROR)
		else
			error(ARGUMENT_ERROR, 2)
		end

		key = key or INITIALIZER_NAMES[1]

		local instance 	= not BaseObject.is_class(object) and object
		local T 	= BaseObject.get_class(object)
		local method 	= BaseObject.super(T, key)

		if instance then
			return method(instance, table_unpack(argtable))
		else
			return method(table_unpack(argtable))
		end
	end

	function BaseObject.is_class(T)
		return type(T) == 'table' and not not rawget(T, CLASS_FIELD__CLASS)
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

	function BaseObject.tostring(object)
		local instance 	= not BaseObject.is_class(object) and object
		local T 	= BaseObject.get_class(object)

		if instance then
			return string.format('(instance of %s)', tostring(T))
		else
			return T:type_name()
		end
	end

	BaseObject.__tostring	= BaseObject.tostring
	BaseObject.__call	= BaseObject.construct_instance
end

objects.BaseObject 	= BaseObject
objects.object 		= BaseObject

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
