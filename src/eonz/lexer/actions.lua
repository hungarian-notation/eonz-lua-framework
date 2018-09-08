local eonz 	= require 'eonz'
local Token 	= require 'eonz.lexer.token'

local actions = {}

function actions.push_mode(mode)
	-- pushes a new lexical mode onto the context's mode stack

	return function (ctx, tok)
		ctx:push_mode(mode)
	end
end

function actions.pop_mode()
	-- pops the top lexical mode off the context's mode stack

	return function (ctx, tok)
		ctx:pop_mode()
	end
end

local function merge_impl(ctx, tok)
	local t1 = ctx:tokens(-2)
	local t2 = ctx:tokens(-1)

	local result = Token.merge(t1, t2)
	ctx:remove_token()
	ctx:remove_token()
	ctx:insert_token(result)
end

function actions.merge()
	return merge_impl
end

function actions.merge_alike()
	-- merges the top two tokens if they have the same id

	return function (ctx, tok)
		local t1 = ctx:tokens(-2)
		local t2 = ctx:tokens(-1)
		if t1:id() == t2:id() then
			merge_impl(ctx, tok)
		end
	end
end

function actions.skip()
	-- completely removes the matched token from the
	-- token stream

	return function(ctx, tok)
		ctx:remove_token()
	end
end

function actions.virtual()

	return function(ctx, tok)
		local new_token = tok:virtualize()
		ctx:remove_token()
		ctx:insert_token(new_token)
		ctx:position(new_token:stop())
	end
end

actions.push 	= actions.push_mode
actions.pop 	= actions.pop_mode

return actions
