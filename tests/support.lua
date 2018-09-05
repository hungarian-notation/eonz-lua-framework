
local lib = {}

function lib.configure()


	lib.eonz = require("eonz") {
		path_roots = {
			{"..", "src"},
			{"."}
		}
	}

	-- print(package.path)

	return lib
end

function lib.print_result(result, short)
	local console		= require('eonz.console')
	local styles 		= require('console-style')
	local indicators 	= require('indicators')

	if not result then
		print(string.format(short and indicators.INLINE_PATTERN
			or "  %s", console.style(styles.passed, short
			and indicators.SUCCESS_VALUE or "PASSED")))
	else
		if short then
			local lines = string.split(tostring(result.error), "\n")

			print(string.format(indicators.INLINE_PATTERN
				.. "\n\n\t%s%s\n",
				console.style(styles.failed,
				indicators.FAILURE_VALUE),
				console.apply(styles.error_location),
				tostring(lines[1])))
		else
			print(string.format("  %s: %s%s",
				console.style(styles.failed, "FAILURE"),
				console.apply(styles.error_location),
				tostring(result.error)))
		end
	end
end

return lib
