local eonz 		= require 'eonz'

local Stream 		= require 'eonz.lexer.stream'
local Context 		= require 'eonz.lexer.context'
local Token 		= require 'eonz.lexer.token'
local GenericLuaParser 	= require 'eonz.lexer.parser'
local grammar		= require 'eonz.introspect.lua-grammar'


local SyntaxNode = eonz.class { name = "eonz::introspect::SyntaxNode" }
do

	function SyntaxNode:__init(what, children, tags)
		self._what 	= what
		self._children 	= children or {}
		self._tags 	= tags or {}
		self._data	= data or {}

		self._rules	= {}
		self._terminals	= {}
		self._origin	= nil
		self:validate()
	end

	function SyntaxNode:children()
		return self._children
	end

	function SyntaxNode:tags(id)
		return id and self._tags[id] or self._tags
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

	function SyntaxNode:tostring(opt)
		opt = eonz.options.from(opt, {
			level = 0
		})

		local sustain_opt = {
			level 	= opt.level;
			pretty 	= opt.pretty;
		}

		local indent_opt = {
			level 	= opt.level + 1;
			pretty 	= opt.pretty;
		}

		local bf = string.builder()

		local indent = opt.pretty and self:depth_under() > 1 and #self:rules() > 1

		local next_opt = indent and indent_opt or sustain_opt

		for i, rule in ipairs(self:rules()) do
			bf:append(" ")

			if indent then

				bf:append("\n")
				bf:append(string.rep("    ", opt.level or 0))
			end

			if Token:is_instance(rule) then
				bf:append("(")
				bf:append(rule:id())
				bf:append(" \"")
				bf:append(rule:text())
				bf:append("\")")
			else
				bf:append(rule:tostring(next_opt))
			end
		end

		return string.format("(%s%s)", self._what[1], tostring(bf))
	end

	SyntaxNode.__tostring = SyntaxNode.tostring
end

local LuaParser = eonz.class { 	name	= "eonz::introspect::LuaParser",
				extends	= GenericLuaParser 			}
do

	function LuaParser:init(opt)
		opt = eonz.options.from(opt, {
			grammar = grammar
		})

		GenericLuaParser.init(self, opt)
	end

	local function define_rule(def)

		local function generator (self, ...)
			self:enter_rule(def.name)

			local result 	= self:leave(def[1](self, ...))
			assert(result, "rule " .. def.name .. " returned nil")
			result:origin(def.name .. (self:trail(1).alternative and ("::" .. self:trail(1).alternative) or ""))
			return result
		end

		LuaParser.RULES = LuaParser.RULES or {}

		LuaParser.RULES[def.name] = {
			name 		= def.name,
			generator	= generator
		}

		LuaParser[def.name] = generator
	end

	local OPERATOR_PRECEDENCE = {
		{ arity=2, assoc='right', '^' },
		{ arity=1, assoc='right', 'not', '#', '-', '~' },
		{ arity=2, assoc='left' , '*', '/', '//', '%' },
		{ arity=2, assoc='left' , '+', '-' },
		{ arity=2, assoc='right', '..' },
		{ arity=2, assoc='left' , '<<', '>>' },
		{ arity=2, assoc='left' , '&' },
		{ arity=2, assoc='left' , '~' },
		{ arity=2, assoc='left' , '|' },
		{ arity=2, assoc='left' , '<', '>', '<=', ">=", "~=", "==" },
		{ arity=2, assoc='left' , 'and' },
		{ arity=2, assoc='left' , 'or' },
	}

	do -- init OPERATOR_PRECEDENCE
		for i, level in ipairs(OPERATOR_PRECEDENCE) do
			level.rank = i
		end
	end

	local function get_precedence(operator, arity)
		for i, level in ipairs(OPERATOR_PRECEDENCE) do
			if table.contains(level, operator) and ((not arity) or (arity == level.arity)) then
				return table
			end
		end

		return nil
	end

	local RVALUE_PREDICT_SET = {
		'identifier',
		'('
	}

	local RVALUE_PRIME_PREDICT_SET = {
		'[',	-- array index
		'.',	-- member index
	}

	local LVALUE_CATEGORY = 'lvalue'

	local RVALUE_CATEGORY = 'rvalue'

	local STRING_TOKENS = {
		'string.single',
		'string.double',
		'string.brackets',
	}

	local INVOCATION_ARGS_PREDICT_SET = {
		'(',	-- direct call
		'{', 	-- table constructor as arg

		-- string as arg

		'string.single',
		'string.double',
		'string.brackets',
	}

	local INVOCATION_PRIME_PREDICT_SET = table.join( INVOCATION_ARGS_PREDICT_SET, { ':' })


	local SINGLE_TOKEN_EXPRESSION = {
		'string.single',
		'string.double',
		'string.brackets',
		'keyword.literal',
		'numeral',
		'keyword.varargs'
	}

	local STATEMENT_STARTING_KEYWORDS = {
		'keyword.do',
		'keyword.goto',
		'keyword.while',
		'keyword.repeat',
		'keyword.if',
		'keyword.for',
		'keyword.function',
		'keyword.local',
		'keyword.break'
	}

	local STATEMENT_PREDICT_SET = table.join(
		{ ';', 'identifier.label' },
		RVALUE_PREDICT_SET, -- indicates assignment or function call
		STATEMENT_STARTING_KEYWORDS
	)

	local EXPRESSION_PREDICT_SET = table.join (
		RVALUE_PREDICT_SET,
		SINGLE_TOKEN_EXPRESSION,
		{
			'keyword.function',
			'operator.unary',
			'operator.nary',
			'{'
		}
	)

	define_rule { name = 'chunk',
		function (self)
			local block = self:block()
			self:expect(nil, "unreachable code after return statement")
			return SyntaxNode({
				'chunk'
			}, {block}, {block=block})
		end
	}

	define_rule { name = 'block',
		function (self)
			local stat 	= {}

			while self:peek(STATEMENT_PREDICT_SET) do
				table.insert(stat, self:statement())
			end

			if #stat == 0 then
				stat = SyntaxNode({
					'empty-statements', 'statements', 'empty'
				}, stat)
			else
				stat = SyntaxNode({
					'statements'
				}, stat)
			end

			local retstat	= self:peek('keyword.return') and self:return_statement()

			if retstat then
				return SyntaxNode({
					'block', 'return'
				}, { stat, retstat })
			else
				return SyntaxNode({
					'block'
				}, { stat })
			end
		end
	}

	define_rule { name = 'return_statement',

		function (self)
			local kw 	= self:consume('keyword.return')
			local exprs 	= self:peek(EXPRESSION_PREDICT_SET) and self:expression_list()

			self:consume_optional(';')

			if exprs then
				return SyntaxNode({
					'return', 'values'
				},{
					kw, exprs
				})
			else
				return SyntaxNode({
					'return', 'nil'
				},{
					kw
				})
			end
		end
	}

	define_rule { name = 'statement',

		function (self)
			self:expect(STATEMENT_PREDICT_SET, "invalid token for start of statement")

			if self:peek(';') then 							self:alternative "null-statement"
				return SyntaxNode({
					'statement', 'empty'
				},{
					self:consume()
				})

			elseif self:peek('identifier.label') then 				self:alternative "label"
				return SyntaxNode({
					'statement', 'label', 'control'
				},{
					self:consume()
				})

			elseif self:peek('keyword.break') then 					self:alternative "break"
				return SyntaxNode({
					'statement', 'break', 'control'
				},{
					self:consume()
				})

			elseif self:peek('keyword.goto') then 					self:alternative "goto"
				return SyntaxNode({
					'statement', 'break', 'control'
				},{
					self:consume('keyword.goto');
					self:consume('identifier');
				})
			elseif self:peek('keyword.do') then 					self:alternative "do"
				local kw, block = self:consume('keyword.do'), self:block();

				return SyntaxNode({
					'statement', 'do'
				},{
					kw, block,
					self:consume('keyword.end')
				}, {
					block = block
				})
			elseif self:peek('keyword.while') then 					self:alternative "while"
				local while_kw, test, do_kw, block, end_kw =
					self:consume('keyword.while'),
					self:expression(),
					self:consume('keyword.do'),
					self:block(),
					self:consume('keyword.end');

				return SyntaxNode({
					'statement', 'while', 'loop', 'control'
				},{
					while_kw, test, do_kw, block, end_kw
				},{
					test = test,
					block = block
				})

			elseif self:peek('keyword.repeat') then 				self:alternative "repeat"

				local repeat_kw, block, until_kw, expr =
					self:consume('keyword.repeat'),
					self:block(),
					self:consume('keyword.until'),
					self:expression()

				return SyntaxNode({
					'statement', 'repeat', 'loop', 'control'
				},{
					repeat_kw, block, until_kw, expr
				},{
					test 	= expr,
					block 	= block
				})

			elseif self:peek('keyword.if') then 					self:alternative "if"

				return self:if_statement()

			elseif self:peek('keyword.for') then 					self:alternative "for"
				return self:for_statement()

			elseif (self:peek('keyword.local') and self:look(2):id('keyword.function'))
				or (self:peek('keyword.function'))
			then 									self:alternative "local function"

				if self:peek('keyword.local') then

					local local_kw, function_kw, id, body =
						self:consume('keyword.local'),
						self:consume('keyword.function'),
						self:consume('identifier'),
						self:function_body();

					return SyntaxNode({
						'declaration', 'function', 'named', 'local'
					},{
						local_kw, function_kw, id, body
					},{
						id	= id;
						body	= body;
					})

				else

					local function_kw, name, body =
						self:consume('keyword.function'),
						self:function_name(),
						self:function_body();

					return SyntaxNode({
						'declaration', 'function', 'named'
					},{
						function_kw, name, body
					},{
						name 	= name;
						body	= body;
					})

				end

			elseif self:peek('keyword.local') then 					self:alternative "local declaration"

				local kw, names = self:consume('keyword.local'), self:name_list()

				if self:peek('=') then
					local eq 	= self:consume('=')
					local exprs 	= self:expression_list()

					return SyntaxNode({
						'declaration', 'local', 'assignment'
					},{
						kw, names, eq, exprs
					})
				else
					return SyntaxNode({
						'declaration', 'local'
					},{
						kw, names
					})
				end
			else
				local rvalue = self:rvalue()

				if rvalue:tags('value_category') == LVALUE_CATEGORY then 		self:alternative "assignment"
					-- can not be a function call statement,
					-- so it is <varlist>

					local lvalues = { rvalue }

					while self:consume_optional(',') do
						table.insert(lvalues, self:lvalue())
					end

					local eq 		= self:consume('=')
					local expressions 	= self:expression_list()

					lvalues = SyntaxNode({
						'assignment-targets', 'lvalues'
					}, lvalues)

					return SyntaxNode({
						'assignment'
					},{
						lvalues, eq, expressions
					},{
						targets = lvalues,
						values 	= expressions
					})

				elseif rvalue:tags('valid_statement') then 				self:alternative "function call"
					-- this flag indicates that the rvalue
					-- is a function call, and is a
					-- valid statement
					return rvalue
				else
					self:syntax_error("not a statement: " .. tostring(rvalue), { after=true })
				end
			end
		end
	}

	define_rule { name = 'if_statement',
		function (self)

			local function consume_if_then()
				local form 	=	self:consume({'keyword.if', 'keyword.elseif'})
				local test 	= 	self:expression()
							self:consume('keyword.then')
				local block 	= 	self:block()

				return SyntaxNode({
					'if-then', form:text()
				},{
					test, block
				},{
					test=test,
					block=block
				})
			end

			local clauses 		= { consume_if_then() }

			local else_clause 	= nil

			while self:peek('keyword.elseif') do
				table.insert(clauses, consume_if_then())
			end

			if self:peek('keyword.else') then
				else_clause = SyntaxNode({
					'else', 'conditional', 'else', 'block'
				},{ self:consume('keyword.else'), self:block() })
			end

			local clause_list = clauses

			clauses = SyntaxNode({
				'if-clauses'
			}, clauses)

			return SyntaxNode({
				'if-statement', 'statement'
			},{
				clauses, else_clause, self:consume('keyword.end')
			},{
				if_clauses = clauses,
				else_clause = else_clause
			})
		end
	}

	define_rule { name = 'for_statement',
		function (self)
			local kw = self:consume('keyword.for')

			if self:peek('identifier', 1) and self:peek('=', 2) then
				-- for i=x,y,z do
				local iter = 	self:consume('identifier')
						self:consume('=')
				local start = 	self:expression()
						self:consume(',')
				local stop = 	self:expression()
				local step = 	self:consume_optional(',')
					and 	self:expression()
						self:consume('keyword.do')
				local block =	self:block()
						self:consume('keyword.end')

				local range

				if step then
					range = SyntaxNode({
						'range', 'step'
					},{
						start, stop, step
					})
				else
					range = SyntaxNode({
						'range'
					},{
						start, stop
					})
				end

				return SyntaxNode({
					'for', 'simple'
				},{
					iter, range, block
				})
			else
				-- for things in thing do
				local names = 	self:name_list()
						self:consume('keyword.in')
				local exprs = 	self:expression_list()
						self:consume('keyword.do')
				local block =	self:block()
						self:consume('keyword.end')

				return SyntaxNode({
					'for', 'enhanced'
				},{
					names, exprs, block
				})
			end
		end
	}

	define_rule { name = 'function_name',
		function (self)
			local name = self:consume('identifier')

			local node = SyntaxNode({ 'function-decl-id \"' .. name:text() .. '\"', 'function-name', 'identifier' }, { name }, {
				name = name,
				root = true })

			while self:consume_optional('.') do
				name = self:consume('identifier')
				node = SyntaxNode({
					'function-decl-id \"' .. name:text() .. '\"', 'function-name', 'index-expression'
				},{ node, name })
			end

			if self:consume_optional(':') then
				name = self:consume('identifier')
				node = SyntaxNode({
					'method-decl-id \"' .. name:text() .. '\"', 'function-name', 'index-expression', 'method-name'
				},{ node, name })
			end

			return node
		end
	}

	define_rule { name = 'function_body',
		function (self)
			return SyntaxNode({
				'function body'
			},{
				self:param_list(), self:block(), self:consume('keyword.end')
			})
		end
	}

	define_rule { name = 'expression',
		function (self)
			local base = self:expression_base()

			if self:peek({'operator.binary', 'operator.nary'}) then
				local op 	= self:consume({'operator.binary', 'operator.nary'})
				local rest	= self:expression()

				local precedence = get_precedence(op, 2)

				return SyntaxNode({
					'binary-operation \"' .. op:text() .. '\"', 'binary-operation', 'expression', 'operation', 'binary'
				},{
					base, op, rest
				},{
					left 		= base;
					right 		= rest;
					op		= op:text();
					precedence	= get_precedence(op:text(), 2);
				})
			else
				return base
			end
		end
	}

	define_rule { name = 'expression_base',
		function (self)
			if self:peek(SINGLE_TOKEN_EXPRESSION) then 				self:alternative "single token"

				if self:peek('string.brackets') then

					local tok 	= self:consume('string.brackets')
					local content 	= tok:source():sub(tok:captures(2), tok:captures(3) - 1)

					return SyntaxNode({
						'string  \"' .. content .. '\"', 'string', 'literal', 'expression'
					},{
						tok
					},{
						text = content,
						value = content
					})

				elseif self:peek({ 'string.single', 'string.double' }) then

					local tok 	= self:consume({ 'string.single', 'string.double' })
					local content 	= tok:text():sub(2, -2)

					return SyntaxNode({
						'string  \"' .. content .. '\"', 'string', 'literal', 'expression'
					},{
						tok
					},{
						text = content,
						value = content
					})

				elseif self:peek('numeral') then

					local NUMERAL_ALTERNATIVES = {
						{ 'numeric-literal', 'literal', 'expression', 'number', 'hex', 'float', 'binary-exponent' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'hex', 'float' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'hex', 'integer', 'binary-exponent' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'hex', 'integer' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'dec', 'float', 'exponent' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'dec', 'float' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'dec', 'integer', 'exponent' },
						{ 'numeric-literal', 'literal', 'expression', 'number', 'dec', 'integer' }
					}

					local tok = self:consume('numeral')

					return SyntaxNode(
						table.join({ 'number \"' .. tok:text() .. '\"' }, NUMERAL_ALTERNATIVES[tok:alt()])
					,{
						tok
					},{
						value = tonumber(tok:text())
					})

				elseif self:peek('keyword.literal') then
					local tok = self:consume('keyword.literal')

					if tok:text() == 'nil' then
						return SyntaxNode({ 'nil-literal', 'literal', 'expression', 'nil' }, { tok }, { value = nil })
					else
						return SyntaxNode({ tok:text() .. '-literal', 'literal', 'expression', 'boolean', tok:text() }, { tok }, { value = (tok:text() == 'true') })
					end

				elseif self:peek('keyword.varargs') then
					local tok = self:consume('keyword.varargs')

					return SyntaxNode({ 'varargs', 'expression' }, { tok })

				else
					error('bug in lua parser: out of alternatives')
				end

			elseif self:peek('keyword.function') then 				self:alternative "anonymous function"

				return SyntaxNode({
					'anonymous-function', 'function', 'anonymous', 'expression'
				},{
					self:consume('keyword.function'),
					self:function_body()
				})

			elseif self:peek({ 'operator.unary', 'operator.nary' }) then 		self:alternative "unary operator"

				local op 	= self:consume({ 'operator.unary', 'operator.nary' })
				local expr	= self:expression()

				return SyntaxNode({
					'unary-operation \"' .. op:text() .. '\"', 'unary-operation', 'operation', 'unary', 'expression'
				},{
					op, expr
				},{
					operand		= expr;
					op 		= op:text();
					expression 	= expr;
					precedence	= get_precedence(op:text(), 2);
				})

			elseif self:peek('{') then 						self:alternative "table constructor"

				return SyntaxNode({
					'table', 'expression'
				},{
					self:table_constructor()
				})

			elseif self:peek(RVALUE_PREDICT_SET) then 				self:alternative "rvalue"
				local rvalue = self:rvalue()

				return rvalue

				--if rvalue.value_category == RVALUE_CATEGORY then
					--[[return SyntaxNode({
						'invocation-result', 'expression', rvalue.valid_statement and 'invocation-result' or 'rvalue'
					},{
						rvalue
					})]]
				--else
					--[[return SyntaxNode({
						'lookup-result', 'expression', 'lvalue'
					},{
						rvalue
					})]]
				--end
			else
				self:syntax_error('unexpected token')
			end

		end
	}

	define_rule { name = 'lvalue',
		function (self)
			local rvalue = self:rvalue()

			if rvalue:tags('value_category') ~= LVALUE_CATEGORY then
				self:syntax_error("result of expression is not an lvalue", { after=true })
			end

			return rvalue
		end
	}

	define_rule { name = 'rvalue',
		function (self)
			local value = self:rvalue_base()

			while self:peek(RVALUE_PRIME_PREDICT_SET) or self:peek(INVOCATION_PRIME_PREDICT_SET) do
				if self:peek(RVALUE_PRIME_PREDICT_SET) then
					local prime = self:rvalue_prime()

					--[[value = {
						value, prime,
						prefix 		= value,
						prime		= prime,
						lookup 		= prime,
						value_category	= LVALUE_CATEGORY,
						valid_statement	= false
					}]]

					value = SyntaxNode({
						'lookup-operation', 'lvalue', 'lookup', 'expression'
					},{
						value, prime
					},{
						base 		= value,
						lookup		= prime,
						value_category	= LVALUE_CATEGORY,
						valid_statement	= false
					})
				elseif self:peek(INVOCATION_PRIME_PREDICT_SET) then
					local prime = self:invocation_prime()

					--[[value = {
						value, prime,
						prefix 		= value,
						prime		= prime,
						invocation	= prime,
						value_category	= RVALUE_CATEGORY,
						valid_statement	= true
					}]]

					value = SyntaxNode({
						'invocation-operation', 'rvalue', 'invocation', 'expression'
					},{
						value, prime
					},{
						base 		= value,
						invocation	= prime,
						value_category	= RVALUE_CATEGORY,
						valid_statement	= true
					})
				end
			end

			return value
		end
	}

	define_rule { name = 'rvalue_base',
		function (self)
			self:expect({"(", "identifier"}, 'expected lvalue or rvalue')

			if self:peek('(') then
				local expr = {
					self:consume('('),
					self:expression(),
					self:consume(')'),
				}

				return SyntaxNode({
					'rvalue-atom', 'expression', 'parenthetical', 'rvalue'
				}, expr, {
					expression 	= expr[2];
					value		= expr[2];
					value_category	= RVALUE_CATEGORY;
				})
			else
				local identifier = self:consume('identifier')

				return SyntaxNode({
					'id \"' .. identifier:text() .. '\"', 'expression', 'identifier', 'lvalue'
				}, expr, {
					identifier 	= identifier;
					value_category	= LVALUE_CATEGORY;
				})
			end
		end
	}

	define_rule { name = 'rvalue_prime',
		function (self)
			if self:peek('[') then
				local expr = {
					self:consume('['),
					self:expression(),
					self:consume(']')
				}

				return SyntaxNode({
					'array-index', 'lookup', 'bracketed'
				}, expr,
				{
					expression = expr[2]
				})
			else
				local expr = {
					self:consume('.'),
					self:consume('identifier')
				}

				return SyntaxNode({
					'id-index \"' .. expr[2]:text() .. '\"', 'lookup', 'identifier', 'named'
				}, expr,
				{
					identifier = expr[2]
				})
			end
		end
	}

	define_rule { name = 'invocation_prime',
		function (self)
			local method_identifier, args

			if self:consume_optional(':') then
				method_identifier = self:consume('identifier')
				args = self:invocation_args()

				return SyntaxNode({
					'method-invocation', 'invocation', 'function', 'method'
				},{
					method_identifier, args
				},{
					args = args,
					method = method_identifier
				})
			else
				args = self:invocation_args()

				return SyntaxNode({
					'plain', 'invocation', 'function', 'plain'
				},{
					args
				},{
					args = args,
					method = false
				})
			end
		end
	}

	define_rule { name = 'invocation_args',
		function (self)

			self:expect(INVOCATION_ARGS_PREDICT_SET,
				"expected function arguments, table-as-arguments, or string-as-arguments")

			if self:consume_optional('(') then
				if self:peek(EXPRESSION_PREDICT_SET) then
					local args = self:expression_list()
					self:consume(")")
					return SyntaxNode({
						'argument-list', 'invocation', 'arguments'
					},{ args })
				else
					self:consume(")")
					return SyntaxNode({
						'empty-argument-list', 'invocation', 'arguments', 'empty'
					},{})
				end
			elseif self:peek('{') then
				local expr = self:table_constructor()

				return SyntaxNode({
					'argument-table', 'invocation', 'table'
				},{ expr })

			elseif self:peek(STRING_TOKENS) then
				local expr = self:expression()

				return SyntaxNode({
					'argument-string', 'invocation', 'string'
				},{ expr })
			end

		end
	}

	define_rule { name = 'table_constructor',
		function (self)
			local open 	= self:consume("{")

			local next_array	= 1
			local fields		= {}

			while not self:peek("}") do

				local bracketed_index 	= self:peek('[')
				local named_index	= self:peek('identifier', 1) and self:peek('=', 2)
				local indexed

				if bracketed_index or named_index then

					if bracketed_index then
						local _1, expr, _2, kw_eq, value_expr =
							self:consume('['),
							self:expression(),
							self:consume(']'),
							self:consume('='),
							self:expression();

						indexed = SyntaxNode({
							'dynamic-field', 'field', 'bracketed', 'hash', 'key'
						}, {
							_1, expr, _2, kw_eq, value_expr
						}, {
							key 		= expr,
							key_expression 	= expr,
							key_value	= expr,
							value 		= value_expr
						})
					else
						local id, kw_eq, value_expr =
							self:consume('identifier'),
							self:consume('='),
							self:expression();

						indexed = SyntaxNode({
							'id-field \"' .. id:text() .. "\"", 'field', 'named', 'hash', 'key'
						},{
							id, kw_eq, value_expr
						},{
							key 		= id;
							key_identifier 	= id;
							key_value	= id:text();
							value 		= value_expr;
						})
					end
				else
					local expression = self:expression()

					indexed = SyntaxNode({
						'array-field', 'field', 'positional', 'array'
					},{
						expression
					},{
						value = expression
					})
				end

				table.insert(fields, indexed)

				if not self:consume_optional({ ',', ';' }) then
					break
				end
			end

			fields = SyntaxNode({
				'table-fields'
			}, fields)

			return SyntaxNode({
				'table-constructor', 'expression', 'rvalue'
			},{
				open, fields, self:consume("}")
			},{
				fields = fields
			})
		end
	}

	define_rule { name = 'expression_list',
		function (self)


			local expressions = {
				self:expression()
			}

			while self:consume_optional(',') do
				table.insert(expressions, self:expression())
			end

			return SyntaxNode({
				'expression-list', 'expressions'
			}, expressions)
		end
	}

	define_rule { name = 'name_list',
		function (self)
			local names 	= {}

			local function next()
				table.insert(names, self:consume('identifier'))
			end

			next()

			while self:peek(',', 1) and self:peek('identifier', 2) do
				self:consume(',')
				next()
			end

			return SyntaxNode({
				'names'
			}, names)
		end
	}

	define_rule { name = 'param_list',

		function (self)
			self:consume('(')
			local names 	= self:peek('identifier', 1) and self:name_list()
			local varargs 	= nil

			if not names then

				names = SyntaxNode({
					'names', 'empty'
				},{},{empty=true})
			end

			if self:peek('keyword.varargs') or self:consume_optional(',') then
				varargs = self:consume('keyword.varargs')
				self:consume(')')

				return SyntaxNode({
					'params'
				},{
					names, varargs
				},{
					names = names,
					varargs = varargs
				})
			else

				self:consume(')')
				return SyntaxNode({
					'params'
				},{
					names
				},{
					names = names,
					varargs = false
				})
			end

		end
	}
end

return LuaParser
