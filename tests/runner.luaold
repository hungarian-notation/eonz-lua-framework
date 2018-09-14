local console	= require('eonz.console')
local styles 	= require('console-style')
local support	= require('support')
local dsl 	= require('dsl')

local function noop() end

local function default_invoker(test, name, test_env)
	local host 	= function() test() end
	return pcall(host)
end

local function run_test(test, test_name, fixture, env)
	io.write(string.format("  %s ", console.style(styles.test_name, test_name)))

	io.write(console.apply(styles.dim))
	for i = 1,60-string.len(test_name) do
		io.write("─")
	end
	io.write(console.apply({}))

	io.write(" ")
	io.flush()

	fixture.before {test=test, name=test_name}

	local results 	= { fixture.invoker(test, test_name) }
	local ok 	= results[1]
	local error 	= results[2]

	fixture.after {test=test, name=test_name}

	local result = (not ok) and { name=test_name, error=error } or nil
	support.print_result(result, true)

	return result
end

return function(test_path, test_group)
	local eonz = require('eonz')
	local tests = {}
	local group = {}

	local env = setmetatable({}, {__index=table.copy(_G)})

	env.group = group
	env.tests = tests
	env.test = tests -- cognate

	for k, v in pairs(dsl) do
		env[k] = v
	end

	local factory = eonz.loadfile(test_path, env)
	local ok, result = pcall(factory, tests, group)

	if not ok then
		error(string.format("error loading test group: %s: %s", test_path, tostring(result)))
	end

	local fixture = {
		invoker = default_invoker,
		before = noop,
		after = noop
	}

	if group['__invoker'] then
		fixture.invoker = group['__invoker']
	end

	if group['__before'] then
		fixture.before = group['__before']
	end

	if group['__after'] then
		fixture.after = group['__after']
	end

	local errors = {}


	local announced = false

	for test_name, test in pairs(tests) do
		if not announced then
			print()
			print(string.format("  [ %s ]", console.style(styles.group_name, test_group)))
			announced = true
			print()
		end
		assert(type(test) == 'function', "test %s in group %s was not a function", test_name, test_path)
		local result = run_test(test, test_name, fixture, env)
		if result then
			table.insert(errors, result)
		end
	end

	if not announced then
		print(string.format("no tests defined in test group: %s", console.style(styles.group_name, test_path)))
	else
		print()
	end

	return errors
end
