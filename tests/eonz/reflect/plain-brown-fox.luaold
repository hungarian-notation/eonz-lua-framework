--[[--
	This module is an attempt to implement every syntax rule for the
	purposes of verification.
--]]--

a, b, c = 1, 2, 3

syntax (

	[[previous]], 		'prior-assignment-statement',
	[[first_child]], 	'assignment-targets',

	[[first_child]],	[[assert_first]], [[assert_leaf]],
				'variable-reference "a"',
				'variable-reference', 'lvalue-expression',
	[[next]],		'variable-reference "b"',
	[[next]],		[[assert_last]], [[assert_leaf]],
				'variable-reference', 'lvalue-expression',
				'variable-reference "c"'

)

::label::

do
	;
	nothing()
end

print("hello, world!")

while io.read("l") do
	if io.error() then
		break
	end
end

goto label

for i = syntax_here("control-flow-condition"), syntax_here("control-flow-condition"), syntax_here("control-flow-condition") do

	syntax (
		[[here]],	"function-invocation-statement",
		[[above]], 	"statement-list-construct",
		[[above]],	"block-construct",
		[[above]],	"for-statement", "for-range-statement", "control-flow-element",
		[[previous]],	"goto-statement", "control-flow-statement",
		[[previous]],	"while-statement", "control-flow-element",
		[[previous]],	"function-invocation-statement",
		[[previous]], 	"do-statement"
	)

end
