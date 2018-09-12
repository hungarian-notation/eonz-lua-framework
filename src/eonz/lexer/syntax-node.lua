local eonz 		= require 'eonz'
local Token 		= require 'eonz.lexer.token'
local info		= require 'eonz.lexer.info'

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

		self._parent	= nil
		self._index	= nil
		self._linked 	= false

		self:validate()
	end

	function SyntaxNode:link(parent, index)
		if self._linked then
			if not rawequal(parent, self._parent) then
				error(tostring(self:context_string()) .. " was already linked by a different node")
			else
				if index ~= self._index then
					error(tostring(self:context_string())
					.. " was already linked to this parent in position #"
					.. tostring(self._index) .. " (rather than #" .. tostring(index) .. ")")
				else
					error(tostring(self:context_string())
					.. " was already linked to this parent at this position")
				end
			end
		else
			self._linked = true
		end

		self._parent = parent
		self._index = index

		for i, child in ipairs(self:rules()) do
			child:link(self, i)
		end

		return self
	end

	--- Recursively applies a functor to a node and all its children in a
	--- depth-first traversal of the AST.
	function SyntaxNode:each(arg)

		--[[--
			Arguments table must either have a function at arg[1] or
			at arg['functor']. This function will be recursively
			applied to this node and all of its children.

			If arg['filter'] is present, it will be called as a
			predicate on each node before it is processed. If
			the filter predicate does not return true, the
			traversal will not continue through the filtered node.

			If arg['matcher'] is present, it will be applied to
			each node as a predicate immediately before the
			functor is applied to that node. If matcher does not
			return true, the functor will not be called on this
			node, but the traversal will continue into any
			children of the current node.

			If the filter predicate stop traversal, the matcher
			predicate will not be called on that node.

			Alternatively, any of the three functions can set
			the `continue` key in the state table (passed as the
			second argument) to false to indicate that
			traversal should not continue beneath the current node.
		--]]--

		local function descend(node, state)

			local local_state 	= table.copy(state)

			local_state.parent 	= state
			local_state.continue 	= true

			if local_state.filter and not local_state.filter(node, local_state) then
				return nil
			end

			if not local_state.matcher or local_state.matcher(node, local_state) then
				local_state.functor(node, local_state)
			end

			if local_state.continue then
				for i, child in ipairs(node:rules()) do
					descend(child, local_state)
				end
			end
		end

		if type(arg) == 'table' then

			local matcher, filter, functor =
				arg.matcher 	or nil,
				arg.filter 	or nil,
				arg.functor 	or arg[1]

			local state = {
				continue 	= true;
				matcher		= matcher;
				filter		= filter;
				functor		= functor;
			}

			descend(self, state)
		end
	end

	function SyntaxNode:parent()
		if self._linked then
			return self._parent
		else
			error('syntax tree is not linked, call :link() on the root node to create parent references')
		end
	end

	function SyntaxNode:index()
		self:parent()
		return self._index
	end

	function SyntaxNode:linked()
		return self._linked
	end

	function SyntaxNode:context_string()
		local child_expr =	#self:rules() == 0 and "«empty»" or
					#self:rules() == 1 and self:rules()[1]:name() or
					"«" .. tostring(#self:rules()) .. "»"

		local downstream = string.format(" > (((%s))) > %s", self:name(), child_expr)

		if self:linked() then
			if self:parent() then
				return self:parent():name() .. downstream
			else
				return "«root»" .. downstream
			end
		else
			return "«not-linked»" .. downstream
		end
	end

	function SyntaxNode:name()
		return self:roles()[1]
	end

	function SyntaxNode:interval()
		return  info.SourceInterval{
			start 	= self:start():start(),
			stop 	= self:stop():stop() - 1,
			source 	= self:source(),
			context = self:context()
		}
	end

	function SyntaxNode:source()
		return self:start() and self:start():source() or nil
	end

	function SyntaxNode:context()
		return self:start() and self:start():context() or nil
	end

	function SyntaxNode:start()
		return self:_select_token 'start'
	end

	function SyntaxNode:stop()
		return self:_select_token 'stop'
	end

	function SyntaxNode:_select_token(which)
		local from, to, step

		from 	= which == 'start' and 1 or self:count()
		to	= white == 'start' and  self:count() or 1
		step 	= from > to and -1 or 1

		for i = from, to, step do
			local child = self:child(i)

			if child then
				if Token:is_instance(child) then
					return child
				end
				local given = child:_select_token(which)
				if given then
					return given
				end
			end
		end
	end

	function SyntaxNode:child(i)
		return self:children()[i]
	end

	function SyntaxNode:count()
		return #self:children()
	end

	function SyntaxNode:empty()
		return #self:children() == 0
	end

	function SyntaxNode:wrap(what, tags)
		return SyntaxNode(what, { self }, tags)
	end

	function SyntaxNode:extend(extensions, tags)
		self._roles 	= table.join(extensions, self._roles)
		self._tags 	= table.merge({}, tags or {}, self._tags or {})
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
		local first_only	= false
		local matched 		= table.array {}

		if type(test) == 'nil' then
			return self:rules()
		end

		if type(test) == 'table' then
			if type(test.first) ~= 'nil' then
				test 		= test.first
				first_only	= true
			end
		end

		test = complete_test(test)

		for i, child in ipairs(self:rules()) do
			if child:roles(test) then
				matched:insert(child)
			end
		end

		if first_only then
			return assert(matched[1], "no such child")
		else
			return matched
		end
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
		self._terminals = {}
		self._rules 	= {}

		local roles = {}

		for i, role in ipairs(self:roles()) do
			if not table.contains(roles, role) then
				table.insert(roles, role)
			end
		end

		self._roles = roles

		for i, child in ipairs(self:children()) do
			if Token:is_instance(child) then
				table.insert(self:terminals(), child)
			else
				table.insert(self:rules(), child)

				if not SyntaxNode:is_instance(child) then
					error(tostring(roles[1]) .. ": #" .. tostring(i)
						.. " is not an instance of "
						.. tostring(SyntaxNode) .. ": "
						.. table.tostring(child, 'pretty'))
				end
			end
		end
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
