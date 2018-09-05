
test['string.split(...)'] = function()
	local string = ",,,this text,is,, a , string"
	local split = string.split(string, ",")

	assert_exists(split, 'split returned nil')
	assert_equals(4, #split)
	assert_equals("this text", 	split[1])
	assert_equals("is", 		split[2])
	assert_equals(" a ",		split[3])
	assert_equals(" string", 	split[4])
end

test['string.split(a, b, {"keep"})'] = function()
	local string = ",,,this text,is,, a , string"
	local split = string.split(string, ",", {keep = true})

	assert_exists(split, 'split returned nil')
	assert_equals(8, #split, "number of resulting elements")
	assert_equals(",", 		split[1])
	assert_equals(",", 		split[2])
	assert_equals(",", 		split[3])
	assert_equals("this text,", 	split[4])
	assert_equals("is,", 		split[5])
	assert_equals(",", 		split[6])
	assert_equals(" a ,",		split[7])
	assert_equals(" string", 	split[8])
end

test['string.split(a, b, {"empties"})'] = function()
	local string = ",,,this text,is,, a , string"
	local split = string.split(string, ",", {empties = true})

	assert_exists(split, 'split returned nil')
	assert_equals(8, #split, "number of resulting elements")
	assert_equals("", 		split[1])
	assert_equals("", 		split[2])
	assert_equals("", 		split[3])
	assert_equals("this text", 	split[4])
	assert_equals("is", 		split[5])
	assert_equals("", 		split[6])
	assert_equals(" a ",		split[7])
	assert_equals(" string", 	split[8])
end

test['string.split(a, b, { max=n }) split with maximum segments'] = function()
	local string = "split;ends;here;these;should;be;one;segment"

	local expected = {
		"split",
		"ends",
		"here",
		"these;should;be;one;segment"
	}

	assert_table_equals(expected, string.split(string, ";", { max = 4 }))
end

test['string.split() error on nil input string'] = function()
	assert_error {
		"input string must not be nil",
		function()
			string.split(nil, ";")
		end
	}
end

test['string.split(a, ", "); multi-character delimiter'] = function()
	local string = ",,,this text,is,, a , string"
	local split = string.split(string, ", ")

	assert_exists(split, 'split returned nil')
	assert_equals(5, #split)
	assert_equals("this", 		split[1])
	assert_equals("text", 		split[2])
	assert_equals("is", 		split[3])
	assert_equals("a",		split[4])
	assert_equals("string", 	split[5])
end

test['string.split("", ...); empty input string'] = function()
	local string = ""
	local split = string.split(string, ",")

	assert_exists(split, 'split returned nil')
	assert_equals(0, #split)
end

test['string.split(a, ""); empty pattern special case'] = function()
	-- as a special case, a zero-length delimiter should split the string
	-- into an array of characters

	local string = "Hello"
	local split = string.split(string, "")

	assert_exists(split, 'split returned nil')
	assert_equals(5, #split)
	assert_equals("H", split[1])
	assert_equals("e", split[2])
	assert_equals("l", split[3])
	assert_equals("l", split[4])
	assert_equals("o", split[5])
end

test['string.join(...) test with mixed input types'] = function()
	local args = {
		"1", 2, "3", 4,
		setmetatable({}, {__tostring=function() return "5" end})
	}

	local result = string.join(unpack(args))

	assert_exists(result, 'join returned nil')
	assert_equals("12345", result)
end

test['string.join() empty arguments test'] = function()
	local result = string.join()

	assert_exists(result, 'join returned nil')
	assert_equals("", result)
end

test['string.builder() general test case'] = function()
	local bf = string.builder()
	assert_exists(bf, 'string.builder() returned nil')

	bf:append("Hello")
	bf:format(", %s", "World")
	bf:append(setmetatable({}, {__tostring=function() return "!" end}))
	local result = tostring(bf)

	assert_exists(result, 'tostring(bf) returned nil')
	assert_type('string', result)
	assert_equals("Hello, World!", result)
end
