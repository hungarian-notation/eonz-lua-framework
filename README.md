# eonz-lua-framework

A framework for prototyping lua games, designed to be relatively non-intrusive
by default.

The goal of this project is to create a framework of useful game-prototyping
utilities that are relatively framework and run-time agnostic, but with platform
specific bindings where needed. The heart of this project is the interplay
between the [runtime](./src/runtime.lua) and [eonz.platform](./src/eonz/platform.lua)
modules.

## `runtime` module

The `runtime` module is a tool for configuring the path of a lua application.
[./src/runtime.lua](./src/runtime.lua) is a standalone module meant to be copied
into dependent projects. Those projects then define their dependencies in a
configuration file and `require` the `runtime` module from their entry point.
The `runtime` module then seeks out the listed dependencies and modifies the
package loader path accordingly.

## `eonz.platform` module

The `eonz.platform` module detects the framework, run-time, lua version and
operating system that lua is running under. It provides a utility to rebuild
the environment's `package.path` to allow packages to define platform-specific
versions of any module.

For example, assume a user running **luajit** on **linux**. Under a
platform-aware `package.path`, when your application requires a module named
`game.networking`, the searchers will check the following in this order:

* `./game/networking.linux.luajit.lua`
* `./linux/luajit/game/networking.lua`
* `./game/networking.linux.lua`
* `./linux/game/networking.lua`

Before giving up on the operating system category, it tries for the `all`
mutator.

* `./game/networking.all.luajit.lua`
* `./all/luajit/game/networking.lua`
* `./game/networking.all.lua`
* `./all/game/networking.lua`

Then is tries without including the operating system mutator.

* `./game/networking.luajit.lua`
* `./luajit/game/networking.lua`
* `./game/networking.lua`

Some candidates are left out for the sake of brevity. The order of precedence
for variants is:

* Operating System    
  * *i.e. 'windows', 'linux', 'osx', 'unknown', 'all'*
* Framework Version   
  * *e.g. 'love11.1'*
* Run-time Version   
  * *e.g. 'luajit2.1'*
* Lua Version   
  * *i.e. 'lua5.1', 'lua5.2', 'lua5.3'*
* Framework Name   
  * *e.g. 'love'*
* Run-time Name   
  * *i.e. 'luajit', 'luaj'*

Each variant chain is applied to each path stub before moving to the next
variant chain. The default path stubs are:

* `?.*.lua`
* `*/?.lua`
* `?/init.*.lua`
* `*/?/init.lua`

Where `*` is replaced by the variant chain, either as a directory hierarchy
or a period-delimited list in the file name. These stubs are configurable
by passing a `path_stubs` option to `eonz.configure()`, but doing so may
break compatibility with the core framework or any modules that use the
default path semantics.
