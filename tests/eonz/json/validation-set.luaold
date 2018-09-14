return {
	{
		[[ true ]],
		true
	},
	{
		[[ false ]],
		false
	},
	{
		[[ null ]],
		nil
	},
	{
		[[ 1000.45e2 ]],
		1000.45e2
	},
	{
		[[ "\r\n\t\b\f\u0058\"\\" ]],
		"\r\n\t\b\fX\"\\"
	},
	{
		[[
			{}
		]],
		{}
	},
	{
		[[
			{ "key" : "value", "another-key" : "another-value" }
		]],
		{ key='value', ['another-key']='another-value' }
	},
	{
		[[
			{
				"key" : [
					"first array element",
					10,
					20,
					-10,
					-20,
					+10,
					+20,
					-10.2,
					 +10003.5251e+10
				]
			}
		]],
		{key={
			'first array element',
			10,
			20,
			-10,
			-20,
			10,
			20,
			-10.2,
			10003.5251e+10
		}}
	},
	{
		[[
			{ "child" : { "child" : {
				"values" : [ null, true, false ] } } }
		]],
		{child={child={values={nil, true, false}}}}
	},
	{
		[[
			{ 	"key\nwith\nescapes"		: "value with \"escaped\" quotes"	,
				"key with unicode: \u0058"	: "value with \\backslashes\\"		}
		]],
		{
			["key\nwith\nescapes"]="value with \"escaped\" quotes",
			["key with unicode: X"]="value with \\backslashes\\"
		}
	}
}
