local eonz 		= require 'eonz'
local Token 		= require 'eonz.lexer.token'

local SyntaxNode = eonz.class { name = "eonz::introspect::SyntaxNode" }
do
	function SyntaxNode:__init(what, children, tags)
		self._roles 	= what or {}
		self._children 	= children or {}
		self._tags 	= tags or {}
		self._data	= data or {}

		self._rules	= {}
		self._terminals	= {}
		self._origin	= nil
		self:validate()
	end

	function SyntaxNode:wrap(what, tags)
		return SyntaxNode(what, { self }, tags)
	end

	function SyntaxNode:extend(extensions, tags)
		self._roles 	= table.join(extensions, self._roles)
		self._tags 	= table.merge({}, tags, self._tags)
		self:validate()
		return self
	end

	function SyntaxNode:revoke(extensions)
		for i, element in ipairs(extensions) do
			while table.contains(self._roles, element) do
				local position = table.index_of(self._roles, element)
				assert(table.remove(self._roles, position) == element)
			end
		end
		self:validate()
	end

	function SyntaxNode:replace(field, table)
		local property_name = "_" .. field
		assert(type(self[property_name]) == type(table))
		self[property_name] = table
		self:validate()
	end

	local function complete_test(test)
		if type(test) == 'string' then
			test = { test }
		end

		if table.is_array(test) then
			test = { any_of=test }
		else
			assert(type(test) == 'table')
		end

		test.none_of	= test.none_of 	or {}
		test.all_of 	= test.all_of 	or {}

		return test
	end

	function SyntaxNode:select(test)
		local matched = table.array {}

		if type(test) == 'nil' then
			return self:rules()
		end

		test = complete_test(test)

		for i, child in ipairs(self:rules()) do
			if child:roles(test) then
				matched:insert(child)
			end
		end

		return matched
	end


	function SyntaxNode:roles(test)
		if type(test) == 'nil' then
			return self._roles
		end

		test = complete_test(test)

		local roles = self._roles

		for i, exluded in ipairs(test.none_of) do
			for j, present in ipairs(roles) do
				if exluded == present then
					return false
				end
			end
		end

		for i, required in ipairs(test.all_of) do
			local found = false

			for j, present in ipairs(roles) do
				if present == required then
					found = true
					break
				end
			end

			if not found then
				return false
			end
		end

		if not test.any_of then
			return true
		end

		for i, searched in ipairs(test.any_of) do
			for j, present in ipairs(roles) do
				if present == searched then
					return  true
				end
			end
		end

		return false
	end

	function SyntaxNode:children()
		return self._children
	end

	function SyntaxNode:tags(id)
		return not id and self._tags or self._tags[id]
	end

	function SyntaxNode:origin(name)
		if name and not self._origin then
			self._origin = name
		end

		return self._origin
	end

	function SyntaxNode:rules()
		return self._rules
	end

	function SyntaxNode:terminals()
		return self._terminals
	end

	function SyntaxNode:validate()
		for i, child in ipairs(self:children()) do
			if Token:is_instance(child) then
				table.insert(self:terminals(), child)
			else
				table.insert(self:rules(), child)

				if not SyntaxNode:is_instance(child) then
					error("not an instance of " .. tostring(SyntaxNode) .. ": " .. table.tostring(child, 'pretty'))
				end
			end
		end

		local roles = {}

		for i, role in ipairs(self:roles()) do
			if not table.contains(roles, role) then
				table.insert(roles, role)
			end
		end

		self._roles = roles
	end

	function SyntaxNode:depth_under()
		if #self:rules() == 0 then
			return 0
		else
			local max = 0
			for i, rule in ipairs(self:rules()) do
				local reported = rule:depth_under()
				if reported > max then
					max = reported
				end
			end
			return max + 1
		end
	end

	local function default_child_decorator(node, child, indent, opt)
		local next_opt = table.copy(opt)
		next_opt.level = opt.level + 1

		if SyntaxNode:is_instance(child) then
			return string.join(indent, SyntaxNode.tostring(child, next_opt))
		else
			return "" --string.join(indent, tostring(child))
		end
	end

	local function default_node_decorator(node, content, indent, opt)
		return string.format("(%s%s)", node:roles()[1], content)
	end

	local function default_indent_decorator(node, rule, opt)
		return opt.pretty and node:depth_under() > 1
			and "\n" .. string.rep("    ", opt.level or 0)
			or " "
	end

	function SyntaxNode:tostring(opt)

		opt = eonz.options.from(opt, {
			level = 1,
			child_decorator	 	= default_child_decorator,
			node_decorator 		= default_node_decorator,
			indent_decorator 	= default_indent_decorator
		})

		local bf = string.builder()

		--local next_opt = indent and indent_opt or sustain_opt

		for i, rule in ipairs(self:children()) do
			bf:append(opt.child_decorator(self, rule, opt.indent_decorator(self, rule, opt), opt))
		end

		return opt.node_decorator(self, tostring(bf), "", opt)
		--string.format("(%s%s)", self._roles[1], tostring(bf))
	end

	SyntaxNode.__tostring = SyntaxNode.tostring
end

return SyntaxNode
