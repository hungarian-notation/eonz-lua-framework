local console	= require('eonz.console')
local styles 	= require('console-style')

local dsl = {}
local types = { 'nil', 'number', 'boolean', 'string', 'table', 'function', 'thread', 'userdata' }

function dsl.fail(message, rest)

	message = message:gsub("«/", 	console.apply(styles.type))
	message = message:gsub("/»", 	console.apply({}))
	message = message:gsub("«", 	console.apply(styles.value))
	message = message:gsub("»", 	console.apply({}))

	error(console.apply({}) .. message .. tostring(rest or ""), 5)
end

local function process_value(value, unquote)
	local function string_interlude(text)
		return console.apply(styles.value) .. text .. console.apply(styles.string_value)
	end

	if type(value) == 'string' and not unquote then
		local str = tostring(value)
		str = str:gsub("\r\n", 	string_interlude "⇠↩")
		str = str:gsub("\r", 	string_interlude "↻")
		str = str:gsub("\n", 	string_interlude "↲")
		str = str:gsub("\t",	string_interlude "⇒")
		str = str:gsub(" ", 	string_interlude "·")
		return "\"" .. console.style(styles.string_value, str) .. "\""
	else
		return tostring(value)
	end
end

local function show_value(tag, ex)
	return string.format("\n\t%s: %s",
		tag or "was", process_value(ex))
end

local function expected_was(ex, was)
	return string.format("\n\texpected: %s\n\t     was: %s",
		process_value(ex),
		process_value(was))
end

function dsl.assert_error(...)
	local expected_message, function_args, target

	local args = {...}

	if #args == 1 and type(args[1]) == 'table' then
		args = args[1]
	end

	assert(#args <= 3)
	assert(#args >= 1)

	for i,arg in ipairs(args) do
		if type(arg) == 'string' then
			assert(not message)
			expected_message = arg
		end

		if type(arg) == 'table' then
			assert(not function_args)
			function_args = arg
		end

		if type(arg) == 'function' then
			assert(not target)
			target = arg
		end
	end

	local status, error = pcall(target, table.unpack(function_args or {}))

	local actual_message = tostring(error)

	if type(error) == 'string' then
		-- remove the location string from the error message

		local parts = error:split(":", { max=3 })
		if #parts == 3 then
			actual_message = parts[3]:trim()
		end
	end

	if status then
		dsl.fail(("function did not raise an error"))
	elseif expected_message and expected_message ~= actual_message then
		dsl.fail("error message did not match the expected value",
			expected_was(expected_message, actual_message))
	end
end

function dsl.assert_raw_equals(expected, actual, variable)
	if not rawequal(expected, actual) then
		dsl.fail((message or "values are not \"rawequal\" to eachother"),
			expected_was(expected, actual))
	end
	return actual
end

dsl.assert_raw_equal 	= dsl.assert_raw_equals
dsl.assert_same 	= dsl.assert_raw_equals

function dsl.assert_table_equals(expected, actual, message)
	if not table.equals(expected, actual) then
		dsl.fail((message or "tables are not equal"),
			expected_was(table.tostring(expected), table.tostring(actual)))
	end
	return actual
end

function dsl.assert_deep_equals(expected, actual, message)
	if not table.equals(expected, actual, true) then
		dsl.fail((message or "tables are not equal"),
			expected_was(table.tostring(expected), table.tostring(actual)))
	end
	return actual
end

function dsl.assert(actual, variable)
	if not actual then
		dsl.fail((message or "expression did not evaluate to true or a \"true\" value"),
			show_value('was', actual))
	end
	return actual
end

function dsl.assert_not(actual, variable)
	if not not actual then
		dsl.fail((message or "expression did not evaluate to «false» or «nil»"),
			show_value('was', actual))
	end
	return actual
end

function dsl.assert_true(actual, variable)
	if type(actual) ~= 'boolean' or actual == false then
		dsl.fail((message or "expression did not evaluate to «/boolean/» «true»"),
			show_value('was', actual))
	end
	return actual
end

function dsl.assert_false(actual, variable)
	if type(actual) ~= 'boolean' or actual == true then
		dsl.fail((message or "expression did not evaluate to boolean false"),
			show_value('was', actual))
	end
	return actual
end

function dsl.assert_equals(expected, actual, message)
	if expected ~= actual then
		dsl.fail(message or "value did not match expected value",
			expected_was(expected, actual))
	end
	return actual
end

dsl.assert_equal = dsl.assert_equals

function dsl.assert_type(expected, value, message)
	local actual = type(value)
	if expected ~= actual then
		dsl.fail((message or "value was not of the expected type"),
			expected_was(expected, actual))
	end
	return value
end

function dsl.assert_not_type(not_expected, value, message)
	local actual = type(value)
	if not_expected == actual then
		dsl.fail((message or "value was of an invalid type"),
			expected_was("anything except " .. tostring(expected), actual))
	end
	return value
end

function dsl.assert_exists(value, message)
	return dsl.assert_not_type('nil', value, message)
end

local function entry_point(callable)
	return function(...)
		return callable(...)
	end
end

for name, callable in pairs(dsl) do
	dsl[name] = entry_point(callable)
end

return dsl
