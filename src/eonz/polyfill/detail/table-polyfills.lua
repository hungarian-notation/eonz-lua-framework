
local options = require "eonz.options"

local function equals_impl(a, b)
	if rawequal (a, b) then
		return true
	end

	if type(a) ~= 'table' or type(b) ~= 'table' then
		return false
	end

	local compared = {}

	for key, v_a in pairs(a) do
		local v_b = b[key]

		if v_a ~= v_b then
			return false
		end

		compared[key] = true
	end

	for key, v_b in pairs(b) do
		if not compared[key] then
			return false
		end
	end

	return true
end

local function eq_impl(a, b)
	if (not a) or (not getmetatable(a)) or (not b) or (not getmetatable(b))
	  or getmetatable(a)['__eq'] ~= getmetatable(b)['__eq'] then
		return false
	else
		return equals_impl(a, b)
	end
end

local function array_impl(arr)
	return setmetatable(arr, table)
end

local function is_array_impl(t)
	if type(t) ~= 'table' then
		return false
	end

	local i = 0

	for _ in pairs(t) do
		i = i + 1
		if t[i] == nil then return false end
	end

	return true
end

local function index_value(index, table_length)
	if index < 0 then
		return table_length + index + 1
	else
		return index
	end
end

local function index_of_impl(t, item)
	for i, value in ipairs(t) do
		if value == item then
			return i
		end
	end

	return nil
end

local function contains_impl(t, item)
	return index_of_impl(t, item) ~= nil
end

local function slice_impl(t, from_index, to_index)
	local copy, count, offset

	copy 		= {}
	count 		= #t
	from_index 	= index_value(from_index, count)
	to_index	= index_value(to_index, count)
	offset 		= from_index - 1

	for i = from_index, to_index do
		copy[i - offset] = t[i]
	end

	return array_impl(copy)
end

local function reverse_impl(t)
	local copy = {}

	for i = 1, #t do
		copy[#t - (i - 1)] = t[i]
	end

	return array_impl(copy)
end

local function is_integer_key(k)
	return type(k) == 'number' and tostring(k):match("^[%d]+$")
end

local function join_impl(...)
	local args 	= {...}
	local found 	= table.array {}

	for k,v in pairs(args) do
		if is_integer_key(k) then
			found:insert {k, v}
		end
	end

	found:sort(function(a, b)
		return a[1] < b[1]
	end)

	local result 	= {}

	for i, t in ipairs(found) do
		for i, value in ipairs(t[2]) do
			table.insert(result, value)
		end
	end

	return array_impl(result)
end

local function merge_impl(t, ...)
	local tables = {...}

	for i, m in ipairs(tables) do
		for k, v in pairs(m) do
			t[k] = v
		end
	end

	return t
end

local function copy_impl(t)
	local copy = {}

	if type(t) ~= 'table' then
		error("expected argument #1 to be of type: table")
	end

	for k, v in pairs(t) do
		copy[k] = v
	end

	return copy
end

local function swap_impl(table, i, j)
	local temp = table[j]
	table[j] = table[i]
	table[i] = temp
end

local function array_copy_impl(table)
	return slice_impl(table, 1, #table)
end

local function compare_records(a, b)
	if tostring(a.k) < tostring(b.k) then
		return true
	elseif tostring(b.k) < tostring(a.k) then
		return false
	elseif a.t < b.t then
		return true
	else
		return false
	end
end

local function record(k, v)
	return {
		k=k,
		t=type(v),
		v=v
	}
end

local function collect(map)
	local records = {}
	for k, v in pairs(map) do
		table.insert(records, record(k, v))
	end
	table.sort(records, compare_records)
	return records
end

local function is_identifier(str)
	return string.match(str, "^[%a_][%a%d_]*$")
end

local function tostring_impl(map, opts)
	if type(map) ~= 'table' then
		if type(map) == 'boolean' or type(map) == 'number' or type(map) == 'nil' then
			return tostring(map)
		else
			return string.format("\"%s\"", tostring(map))
		end
	end

	local metatable = getmetatable(map)

	if metatable and metatable.__tostring and metatable.__tostring ~= tostring_impl then
		return string.format("\"%s\"", tostring(map))
	end

	opts = options.from(opts, {
		level 	= 1,
		indent 	= "  ",
		visited = (opts and opts.visited) or {},
		pretty	= false,
		arrays 	= true
	})

	if table.contains(opts.visited, map) then
		return "«recursion»"
	else
		table.insert(opts.visited, map)
	end

	local next_opts = copy_impl(opts)
	next_opts.level = opts.level + 1

	local records = collect(map)
	local bf = string.builder()

	local function indent(offset)
		offset = offset or 0
		if opts.pretty then
			bf:append(string.rep(opts.indent, opts.level + offset))
		end
	end

	local function next_line(alt)
		if opts.pretty then
			bf:append("\n")
		elseif alt then
			bf:append(alt)
		end
	end

	if opts.arrays and is_array_impl(map) then
		bf:append("[")

		for i, value in ipairs(map) do
			if i ~= 1 then
				bf:append(",")
				next_line(" ")
			else
				next_line()
			end

			indent()
			bf:format("%s", tostring_impl(value, next_opts))
		end

		next_line()
		indent(-1)
		bf:append("]")
	else
		bf:append("{")
		for i, record in ipairs(records) do
			if i ~= 1 then
				bf:append(", ")
			end

			next_line()
			indent()

			local key_string

			if type(record.k) == 'number' or type(record.k) == 'boolean' or type(record.k) == 'nil' then
				key_string = "[" .. tostring(record.k) .. "]"
			elseif type(record.k) == 'string' then
				key_string = is_identifier(record.k) and (record.k) or ("[\"" .. tostring(record.k) .. "\"]")
			else
				key_string = "[" .. tostring(record.k) .. "]"
			end

			bf:format("%s=%s", key_string, tostring_impl(record.v, next_opts))
		end
		next_line()
		indent(-1)
		bf:append("}")

	end

	return tostring(bf)
end

local function stable_sort_impl(t, compare)
	local swap = swap_impl
	compare = compare or function(a, b) return a < b end

	local function iterate()
		local mutated = false

		for i = 1, #t - 1 do
			if compare(t[i+1], t[i]) then
				swap(t, i, i+1)
				mutated = true
			end
		end

		return mutated
	end

	repeat until not iterate()

	return t
end

local polyfills = {
	{ name = 'array',	impl = array_impl	},
	{ name = '__index',	impl = table		},
	{ name = '__eq',	impl = eq_impl		},
	{ name = '__tostring',	impl = tostring_impl 	},

	-- these functions operate on tables as if they
	-- were arrays

	{ name = 'is_array',	impl = is_array_impl	},
	{ name = 'array_copy',	impl = array_copy_impl 	},
	{ name = 'slice',	impl = slice_impl 	},
	{ name = 'join', 	impl = join_impl 	},
	{ name = 'swap', 	impl = swap 		},
	{ name = 'reverse',	impl = reverse_impl 	},
	{ name = 'stable_sort',	impl = stable_sort_impl },
	{ name = 'index',	impl = index_of_impl	},
	{ name = 'index_of',	impl = index_of_impl	},
	{ name = 'contains',	impl = contains_impl	},

	-- these functions are aware of key-value pairs
	-- as well as numerical indices

	{ name = 'equals',	impl = equals_impl	},
	{ name = 'merge', 	impl = merge_impl 	},
	{ name = 'copy',	impl = copy_impl 	},
	{ name = 'tostring',	impl = tostring_impl 	},
}

if _G['unpack'] and not table.unpack then
	table.insert(polyfills, {name = 'unpack', impl=_G['unpack']})
end

if table.unpack and not _G['unpack'] then
	_G['unpack'] = table.unpack
end

return polyfills
