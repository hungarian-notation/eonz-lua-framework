local applied	= false
local applying	= false

local CORE_EXTENSIONS = {
	string 	= 'eonz.polyfill.detail.string_extensions';
	table	= 'eonz.polyfill.detail.table_extensions';
}

local polyfill = {
	_loaded = {};
	_locals	= {};
}

--- Gets the module path for the extensions for the named module.
---
--- e.g. polyfill.extension_path('string') evaulates to the path to the module
--- that defines our string extensions.
function polyfill.extensions_module_path(extname)
	return assert(CORE_EXTENSIONS[extname], "no extensions for: " .. tostring(extname))
end

function polyfill.load_extensions(extname)
	local extensions 	= require(polyfill.extensions_module_path(extname))
	local record 		= { list = {}, map = {} }

	for i, extension in ipairs(extensions) do
		table.insert(record.list, extension)
		record.map[extension.name] = extension
	end

	polyfill._loaded[extname] = record

	return record
end

function polyfill.get_extensions(extname)
	return polyfill._loaded[extname] or polyfill.load_extensions(extname)
end

local function get_implementation(ext)
	if not ext.definition then
		ext.definition = assert(ext.factory, tostring(ext.name) .. " must define a definition or factory")()
	end

	return ext.definition
end

function polyfill.get_extension(base, ext)
	local definition = polyfill.get_extensions(base)
	return assert(get_implementation(definition.map[ext]), "no such extension")
end

function polyfill.load_local(extname, target)
	if not (CORE_EXTENSIONS[extname]) then
		return nil
	end

	--print ("extending: ", extname)

	local definition	= polyfill.get_extensions(extname)
	local basis 		= assert(_G[extname], 'missing ' .. extname .. ' from global scope')
	target			= target or {}

	if target ~= basis then
		for k, v in pairs(basis) do
			target[k] = v;
		end
	end

	for i, ext in ipairs(definition.list) do
		local name 		= ext.name
		local definition	= get_implementation(ext)
		target[name] 		= definition
	end

	polyfill._locals[extname] = target

	local metatable = {}

	function metatable.__index(T, key)
		error("no implementation for: " .. extname .. "." .. tostring(key), 2)
	end

	return setmetatable(target, metatable)
end

function polyfill.extended(extname)
	--print ("getting extension: ", extname)

	return polyfill._locals[extname]
		or (polyfill.load_local(extname))
		or (_G[extname] or error('no such module: ' .. extname))
end

function polyfill.extend(extname, target)
	--print('installing extensions for: ' .. extname)

	local extensions = polyfill.get_extensions(extname)

	-- extensions should be an array-like table of
	-- extension forms structured as:
	--	{ name=«string», definition=«function» }

	for i, extension in ipairs(extensions.list) do
		local name, definition =
		 	assert(extension.name, 		extname .. ": missing name on polyfill #"
								.. tostring(i)),
		 	assert(extension.definition, 	extname .. ": missing definition on polyfill #"
								.. tostring(i))

		if target[name] then
			error("target already has a field named: " .. name)
		else
			--print('installing: ' .. name)
			target[name] = definition
		end
	end
end

local meta_polyfill = {}

function meta_polyfill.__index(pf, key)
	--print('indexing polyfill')
	return polyfill.extended(key)
end

return setmetatable(polyfill, meta_polyfill);
