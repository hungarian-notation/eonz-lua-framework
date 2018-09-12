# AST Roles for the introspection API

The introspection API builds an AST of arbitrary Lua source code. It uses
the roles/tags/content idiom defined by the `eonz.lexer.syntax-node` module.

Each AST rule node has a sequence of roles that describe its purpose in
the source code. The introspection API will provide a set a tools to walk
these AST representations, using patterns of rules to match patterns of
source code.

## Categorical Roles

Every node must declare at least one of the following categorical roles:

* `chunk`
* `statement`
* `identifier`
* `expression`
* `operator`
* `construct`

These roles provide a basic level at which we can reason about an AST.

### `chunk`

Used exclusively by the root node as its only declared role.

### `statement`

A top level statement. See below for more details.

### `identifier`

An identifier keyword in its role in the source. Depending on the role it
serves, it may be declare the `reference` or `declaration` roles.

### `expression`

A broad category that includes literals, operations, function invocations, and
anonymous table and function objects.

### `operator`

An operator. These will always appear as children of an `operation-expression`

## Statements

All nodes that declare the `statement` role will also declare exactly one of
the following roles:

	'local-function-declaration-statement';
	'global-function-declaration-statement';
	'member-function-declaration-statement';
	'function-invocation-statement'; 			-- a function call at the statement level
	'local-declaration-statement';				-- declare local scope variable without assigning
	'local-assignment-statement';				-- declare and possibly assign local scope variable
	'prior-assignment-statement'; 				-- non-declaring assigning, to global or local
	'do-statement';
	'if-statement';
	'for-range-statement';
	'for-iterator-statement';
	'while-statement';
	'repeat-statement';
	'break-statement';
	'goto-statement';
	'label-statement';
	'empty-statement';
	'return-statement';

%%TODO%%

## Expressions

Literal values declare the `literal` role. This includes table and function
literals. True constants will declare the `constexpr` role, and will have tags
holding their Lua type and their actual Lua value in the correct type:

	constexpr	= 	«lua-type-string»;
	value		= 	«lua-value»;

%%TODO%%

## Operations

All operation nodes declare the role `operation-expression`. Depending on the
operator, they may either declare `unary-operation` or `binary-operation` as
their nominative role.

Operations begin the parse as a linked-list of AST nodes without any
consideration for operator precedence. Before they are passed out of the
expression rule, they are rewritten into a tree that describes the proper
operator precedence.

Operations are best inspected via their tags. All nodes that declare the
`operation-expression` role have the following tags:

	operator 	= «operator-token»;
	operands	= { [l, ] r };
 	sequence 	= «original-sequence»;

The operator tag hold the Token instance for the operator, and the operands
will hold the expression or expressions.
