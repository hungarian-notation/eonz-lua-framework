# Introspection API

The reflection API provides utilities for tokenizing, parsing, and analyzing
Lua source code from within a running Lua application or as a standalone tool.

## Upcoming Features:

### Online Features:

These are hypothetical, depending on what performance I can wrangle out of
this thing.

The idea is to provide require-time code mutators that can be individually
enabled, disabled, and augmented with custom mutators written in Lua.

	* Conditional removal of inline debug code.
	* Rewriting of some conditionally used arguments to enable lazy evaluation.

### Offline Features:

	* Documentation generation from comments and source code.
	* Basic linting and bug-checking.
	* Globally-scoped assignment detection.
	* Compatibility analysis, determine what globals the package uses.
