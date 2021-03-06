local eonz 	= require 'eonz'
local table 	= eonz.pf.table
local string 	= eonz.pf.string
local console	= require 'eonz.console'

local function readfile(file)
    local f 		= assert(io.open(file, "rb"))
    local content	= f:read("*all")
    f:close()
    return content
end

local Stream 		= require 'eonz.lexer.stream'
local SyntaxNode	= require 'eonz.lexer.syntax_node'
local Context 		= require 'eonz.lexer.context'
local info		= require 'eonz.lexer.info'
local Source 		= info.Source
local lua_grammar	= require 'eonz.reflect.lua_grammar'
local LuaParser		= require 'eonz.reflect.lua_parser'

local target_roots	= {}
local targets 		= string.split(eonz.platform.capture("find ../src -name \"*.lua\""), "\n")
local contracts 	= require('eonz.reflect.general-contracts')

local BUILTIN_NAMES = {
	"syntax", "syntax_here", "syntax_next", "syntax_above"
}

local function get_builtin(node)
	local expression = nil

	if node:roles("function-invocation-statement") then
		expression = node:rules()[1]
	elseif node:roles("function-invocation-expression") then
		expression = node
	else
		return nil -- not a valid builtin ast
	end

	local target 	= expression:rules()[1]

	local name	= nil

	if not target:roles("invocation-target-construct") then
		return nil -- not a valid builtin ast
	else
		target = target:rules()[1]
	end

	if not target:roles("variable-reference") then
		return nil -- not a valid builtin ast
	else
		name = target:child(1):text()
	end

	if not table.contains(BUILTIN_NAMES, name) then
		return nil -- not a valid builtin name
	end

	local args = expression:rules()[2]

	if args:roles("list-arguments-construct") then
		args = args:roles("empty") and {} or args:rules()[1]:rules()
	elseif args:roles("string-arguments-construct") then
		args = args:select("string-literal")
	end

	local results = {}

	for i = 1, #args do
		assert(SyntaxNode:is_instance(args[i]), type(args[i]))
		results[i] = args[i]:tags('value')
	end

	--print( name, table.tostring(results))

	return {
		name = name;
		args = results;
		node = node;
	}
end

local BUILTIN_HANDLERS = {}

local function evaluate_builtin(builtin)
	BUILTIN_HANDLERS[builtin.name](builtin.node, table.unpack(builtin.args))
end

function BUILTIN_HANDLERS.syntax_here(node, test)
	local container = node:parent()
	assert_true(container:roles(test), string.format("node %s does not have role %s", container:context_string(), test))
end

function BUILTIN_HANDLERS.syntax_next(node, test)
	local container 	= node:parent()
	local position 		= table.index_of(container:rules(), node)
	local next		= container:rules()[position + 1]
	assert_exists(next, "there is no \"next\" to check")
	assert_true(next:roles(test), string.format("node %s does not have role %s", next:context_string(), test))
end

function BUILTIN_HANDLERS.syntax_above(node, ...)

	local sequence 		= { ... }

	local container 	= node:parent()
	local position 		= table.index_of(container:rules(), node)
	local target 		= container

	while #sequence > 0 do
		local next_test 	= table.remove(sequence, 1)
		target 			= assert_exists(target:parent(), "attempted to match above the root node")
		assert_true(target:roles(next_test), string.format("node %s does not have role %s", target:context_string(), next_test))
	end
end

function BUILTIN_HANDLERS.syntax(node, ...)


	local MOTIONS = {
		here = function (node)
			return node
		end,

		above = function (node)
			return assert(assert(node.parent) and node:parent())
		end,

		previous = function (node)
			return assert(assert(node, 'node was null') and assert(node.parent, "node.parent not defined") and node):parent():rules()[node:index() - 1]
		end,

		next = function (node)
			return node:parent():rules()[node:index() + 1]
		end,

		first_child = function (node)
			assert_true(#node:rules() > 0, "no children to walk")
			return node:rules()[1]
		end,

		last_child = function (node)
			assert_true(#node:rules() > 0, "no children to walk")
			return node:rules()[#node:rules()]
		end,

		assert_first = function (node)
			assert_equal(1, node:index(), "node was not the first rule in its parent rule")
			return node
		end,

		assert_last = function (node)
			assert_equal(#node:parent():rules(), node:index(), "node was not the last rule in its parent rule")
			return node
		end,

		assert_only_child = function (node)
			assert_equal(1, #node:parent():rules(), "parent has more than one child rule")
			return node
		end,

		assert_leaf = function (node)
			assert_true(#node:rules() == 0, "node is not a leaf")
			return node
		end,

		assert_branch = function (node)
			assert_true(#node:rules() > 0, "node is not a branch")
			return node
		end,

		assert_root = function (node)
			assert_not(node:parent(), "node is not the root")
			return node
		end
	}

	local sequence 		= { ... }
	local target 		= node

	while #sequence > 0 do
		local next_term = table.remove(sequence, 1):trim()

		if MOTIONS[next_term] then
			target = MOTIONS[next_term](target)
			assert_exists(target)
		else
			print("looking at: ", target:context_string(), "vs", next_term)
			assert_true(target:roles(next_term), string.format("node %s does not have role %s", target:context_string(), next_term))
		end
	end

	print(table.tostring(sequence))
end

do
	local source = Source {
		text = readfile("./eonz/reflect/plain-brown-fox.lua");
		name = "./eonz/reflect/plain-brown-fox.lua";
	}

	local parser = LuaParser {
		source = source
	}

	local chunk = parser:chunk()

	local ast = chunk:link()

	local builtins = {}

	ast:each {
		function (e, state)
			local builtin 	= get_builtin(e)

			if builtin then
				state.continue 	= false
			end

			table.insert(builtins, builtin)
		end
	}

	for i, builtin in ipairs(builtins) do

		tests[string.format("%s at %s",
			builtin.name, tostring(builtin.node:interval():start_position()))] = function ()
			evaluate_builtin(builtin)
		end

	end
end
