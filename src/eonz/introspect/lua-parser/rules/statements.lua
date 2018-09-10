-- @auto-fold regex /^[\t](local )?(function|[a-zA-Z_]+\s*[=]).*$/  /alternative/

local eonz = require "eonz"
local SyntaxNode = require 'eonz.lexer.syntax-node'
return function(LuaParser, define_rule)

	define_rule { name = 'return_statement',

		function (self)
			local kw 	= self:consume('keyword.return')
			local exprs 	= self:peek(LuaParser.EXPRESSION_PREDICT_SET) and self:expression_list()


			if exprs then
				return SyntaxNode({
					'return-statement',
					'statement'
				},{
					kw, exprs, self:consume_optional(';')
				})
			else
				return SyntaxNode({
					'return-statement',
					'statement',
					'empty-return-statement'
				},{
					kw, self:consume_optional(';')
				})
			end
		end
	}

	define_rule { name = 'statement',
		function (self)
			self:expect(LuaParser.STATEMENT_PREDICT_SET, "invalid token for start of statement")

			if self:peek(';') then 							self:alternative "null-statement"
				return SyntaxNode({
					'empty-statement', 'statement'
				},{
					self:consume()
				})

			elseif self:peek('identifier.label') then 				self:alternative "label"
				return SyntaxNode({
					'label-statement', 'statement', 'control-statement', 'control-flow-element'
				},{
					self:consume()
				})

			elseif self:peek('keyword.break') then 					self:alternative "break"
				return SyntaxNode({
					'break-statement', 'statement', 'control-statement', 'control-flow-statement', 'control-flow'
				},{
					self:consume()
				})

			elseif self:peek('keyword.goto') then 					self:alternative "goto"
				return SyntaxNode({
					'goto-statement', 'statement', 'control-statement', 'control-flow-statement', 'control-flow'
				},{
					self:consume('keyword.goto');
					self:identifier {
						'goto-target-identifier',
						'label-identifier' }
				})
			elseif self:peek('keyword.do') then 					self:alternative "do"
				local kw, block = self:consume('keyword.do'), self:block();

				return SyntaxNode({
					'do-statement', 'statement', 'control-statement'
				},{
					kw, block,
					self:consume('keyword.end')
				}, {
					block = block
				})
			elseif self:peek('keyword.while') then 					self:alternative "while"
				local while_kw, test, do_kw, block, end_kw =
					self:consume('keyword.while'),

					LuaParser.flatten_varargs(self:expression()):wrap {
						'control-flow-condition';
						'control-flow-expression';
						'expression';
						'rvalue-expression';
						'control-flow';
					},

					self:consume('keyword.do'),
					self:block(),
					self:consume('keyword.end');

				block = block:extend {
					'while-block-construct', 'control-flow-element', 'control-flow'
				}

				return SyntaxNode({
					'while-statement', 'statement', 'control-statement', 'control-flow-element', 'control-flow'
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
					LuaParser.flatten_varargs(self:expression()):wrap {
						'control-flow-condition';
						'control-flow-expression';
						'expression';
						'rvalue-expression';
						'control-flow';
					}

				block = block:extend {
					'repeat-block-construct', 'control-flow-element', 'control-flow'
				}

				return SyntaxNode({
					'repeat-statement', 'statement', 'control-statement', 'control-flow-element', 'control-flow'
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
			then

				if self:peek('keyword.local') then				self:alternative "local function"

					local local_kw, function_kw, id, body =
						self:consume('keyword.local'),
						self:consume('keyword.function'),
						self:variable_declaration{
							'function-declaration'
						},
						self:function_body();


					return SyntaxNode({
						'local-function-declaration-statement', 'local-function-declaration', 'declaration', 'statement'
					},{
						local_kw, function_kw, id, body
					},{
						id	= id;
						body	= body;
					})

				else								self:alternative "non-local function"

					local function_kw, name, body =
						self:consume('keyword.function'),
						self:function_name(),
						self:function_body();

					return SyntaxNode({
						'function-declaration-statement', 'declaration',  'statement'
					},{
						function_kw, name, body
					},{
						name 	= name;
						body	= body;
					})

				end

			elseif self:peek('keyword.local') then 					self:alternative "local declaration"

				local kw, names =
					self:consume('keyword.local'),
					self:name_list {'local-variable-declaration', 'declaration', 'target-construct', 'target-list-construct'}

				if self:peek('=') then
					local eq 	= self:consume('=')
					local exprs 	= self:expression_list {
						'assignment-expression-list'
					}
					return SyntaxNode({
						'local-assignment-statement',
						'assignment-statement',
						'declaration',
						'local',
						'assignment-statement',
						'statement'
					},{
						kw, names, eq, exprs
					},{
						declarations = names;
						targets = names;
						values = exprs;
					})
				else
					return SyntaxNode({
						'local-declaration-statement',
						'local-declaration',
						'variable-declaration',
						'declaration',
						'local',
						'statement'
					},{
						kw, names
					},{
						declarations = names
					})
				end
			else
				local rvalue = self:rvalue(true)

				if rvalue:tags('value_category') == LuaParser.LVALUE_CATEGORY then 		self:alternative "assignment"
					-- can not be a function call statement,
					-- so it is <varlist>

					local lvalues = { rvalue }

					while self:consume_optional(',') do
						table.insert(lvalues, self:lvalue())
					end

					local eq 		= self:consume('=')

					local exprs 		= self:expression_list {
						'assignment-expressions', 'expression-list', 'list-construct', 'construct'
					}

					lvalues = SyntaxNode({
						'assignment-targets', 'assignment-targets-construct', 'construct'
					}, lvalues)

					return SyntaxNode({
						'prior-assignment-statement', 'assignment-statement', 'statement'
					},{
						lvalues, eq, exprs
					},{
						targets = lvalues,
						values 	= exprs
					})

				elseif rvalue:tags('valid_statement') then self:alternative "function call"
					-- this flag indicates that the rvalue
					-- is a function call, and is a
					-- valid statement
					return LuaParser.flatten_varargs(rvalue):wrap {
						'function-invocation-statement',
						'statement'
					}
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
				local test 	= 	LuaParser.flatten_varargs(self:expression()):wrap {
					'control-flow-condition';
					'control-flow-expression';
					'expression';
					'rvalue-expression';
					'control-flow';
				}
							self:consume('keyword.then')
				local block 	= 	self:block()

				return SyntaxNode({
					'if-then-construct', form:text() .. "-then-construct", "construct", 'control-flow-element', 'control-flow'
				},{
					form, test, block
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
					'else-construct', 'construct', 'control-flow-element', 'control-flow'
				},{ self:consume('keyword.else'), self:block() })
			end

			local clause_list = clauses

			clauses = SyntaxNode({
				'if-clauses-construct', 'construct', 'control-flow-element', 'control-flow'
			}, clauses)

			return SyntaxNode({
				'if-statement',
				'statement',
				'control-statement',
				'control-flow-element',
				'control-flow'
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
				local iter = 	self:variable_declaration{
					'for-variable-declaration',
					'control-flow-variable',
					'control-flow',
					'declaration'
				}
						self:consume('=')
				local start = 	LuaParser.flatten_varargs(self:expression()):wrap {
					'control-flow-condition';
					'control-flow-expression';
					'expression';
					'rvalue-expression';
					'control-flow';
				}
						self:consume(',')
				local stop = 	LuaParser.flatten_varargs(self:expression()):wrap {
					'control-flow-condition';
					'control-flow-expression';
					'expression';
					'rvalue-expression';
					'control-flow';
				}
				local step = 	self:consume_optional(',')
					and 	LuaParser.flatten_varargs(self:expression()):wrap {
						'control-flow-condition';
						'control-flow-expression';
						'expression';
						'rvalue-expression';
						'control-flow';
					}
						self:consume('keyword.do')
				local block =	self:block()
						self:consume('keyword.end')

				local range

				block = block:extend {
				'for-block-construct', 'control-flow-element', 'control-flow'
				}

				if step then
					range = SyntaxNode({
						'for-range-construct', 'construct',
						'control-flow-construct',
						'control-flow'
					},{
						start, stop, step
					},{
						start = start,
						stop = stop,
						step = step
					})
				else
					range = SyntaxNode({
						'for-range-construct', 'construct',
						'control-flow-construct',
						'control-flow'
					},{
						start = start,
						stop = stop,
						step = false
					})
				end

				return SyntaxNode({
					'for-range-statement',
					'for-statement',
					'control-statement',
					'statement',
					'control-flow-element',
					'control-flow'
				},{
					kw, iter, range, block
				})
			else
				-- for things in thing do
				local names = 	self:name_list ({
					'for-variable-declaration',
					'control-flow-variable',
					'control-flow',
					'declaration'
				},{
					'for-variable-list',
					'control-flow'
				})
						self:consume('keyword.in')
				local exprs = 	self:expression_list():extend {
					'for-expression-list', 'control-flow-condition', 'control-flow'
				}
						self:consume('keyword.do')
				local block =	self:block()
						self:consume('keyword.end')

				block = block:extend {
				'for-block-construct', 'control-flow-element', 'control-flow'
				}

				return SyntaxNode({
					'for-iterator-statement',
					'for-statement',
					'control-statement',
					'statement',
					'control-flow-element',
					'control-flow'
				},{
					kw, names, exprs, block
				})
			end
		end
	}
end
