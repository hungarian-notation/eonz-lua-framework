
tests['error message matching'] = function()
	assert_error {
		function()
			error("some error message")
		end
	}

	assert_error {
		function()
			assert_error {
				"some other error message",
				function()
					error("some error message")
				end
			}
		end
	}
end

tests['assert_error() argument table'] = function()
	assert_error { { 'red', 'trigger', 'orange' },
		function( arg1, arg2, arg3 )
			if arg2 == 'trigger' then error() end
		end
	}

	assert_error {
		function(arg)
			if arg == 'trigger' then error() end
		end,
	{'trigger'} }

	assert_error { "this is the error message", {'trigger'},
		function(arg)
			if arg == 'trigger' then error("this is the error message") end
		end
	}
end

tests['assert_error() general form'] = function()
	assert_error {
		function()
			error()
		end
	}

	assert_error {
		function()
			-- this assert_error should throw an error because
			-- the function it is called on throws no error
			
			assert_error { function() --[[ no error ]] end }
		end
	}
end
