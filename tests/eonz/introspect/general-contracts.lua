
local dsl 	= require("dsl")
local contracts = {}

local function define_contract(contract)
	contract.invoke = contract.invoke or contract[1]
	assert(type(contract) == 'table')
	assert(type(contract.name) == 'string')
	assert(type(contract.invoke) == 'function')
	table.insert(contracts, contract)
end

local function role_implies(match, implies)
	local function apply(node)
		if node:roles(match) and not node:roles(implies) then
			dsl.fail(string.format("failed implication:\n\n\t%s\n\n\t\t->\n\n\t%s\n\n\troles: %s\n\n\tnode: %s",
				table.tostring(match),
				table.tostring(implies),
				table.tostring(node:roles()),
				tostring(node)))
		end
		for i, child in ipairs(node:rules()) do
			apply(child)
		end
	end
	return apply
end

local function each_node(scope)
	local functor = assert(type(scope[1]) == 'function' and scope[1])

	local function apply(node)
		local applicable = true

		applicable = applicable and ((not scope.matching) or (node:roles(scope.matching)))

		if applicable then
			functor(node)
		end

		for i, child in ipairs(node:rules()) do
			apply(child)
		end
	end

	return apply
end

local DISALLOW_ROLES = {
	'nil', 'boolean', 'rvalue', 'lvalue', 'do', 'loop', 'break', 'while', 'table', 'elseif', 'if', 'then'
}

local CATEGORIES = {
	"chunk", "construct", "operator", "identifier", "expression", "statement"
}

do
	define_contract { name = "variable expansion and expansion contexts";
		each_node { matching = { none_of = {'expansion-context'} };
			function (node)
				local expanding_children = node:select("variable-length-expression")
				if #expanding_children > 0 then
					dsl.fail("non-expansion-context had unsuppressed variable-length-expression: "
						.. "\n\n" .. node:tostring('pretty'))
				end
			end
		}
	}

	define_contract { name = "DISALLOW_ROLES";
		role_implies(DISALLOW_ROLES, { none_of = DISALLOW_ROLES})
	}

	define_contract { name = "ABSOLUTE_CATEGORIES";
		role_implies({ none_of=CATEGORIES }, { any_of=CATEGORIES })
	}

	define_contract { name = "expressions have values";
		role_implies({'expression'}, { any_of = {'rvalue-expression', 'lvalue-expression', 'varargs-expression'} })
	}

	define_contract { name = 'expansion-context is list-construct',
		role_implies({'expansion-context'}, {'list-construct', 'array-field'})
	}

end

return contracts
