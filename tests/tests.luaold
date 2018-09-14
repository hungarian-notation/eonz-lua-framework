local support 	= require('support').configure()

require('eonz.polyfill')()

local console 	= require('eonz.console')
local styles 	= require('console-style')

local collect = require("collect-tests")

local function run_all(tests)
	local errors = {}

	for i, test in ipairs(tests) do
		local results = require('runner')(test.path, test.group)

		for i, e in ipairs(results) do
			table.insert(errors, e)
		end
	end

	return errors
end

local tests 	= collect()
local errors 	= run_all(tests)

if #errors > 0 then
	print(console.style(styles.failed, string.format("ENCOUNTERED %d ERROR(S)", #errors)))
	for i, error in ipairs(errors) do
		print()
		support.print_result(error)
	end
	os.exit(1)
else
	print(console.style(styles.passed, "ALL TESTS PASSED."))
	print()
end
