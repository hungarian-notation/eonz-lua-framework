local eonz 	= require("eonz")
local console	= require('eonz.console')

local function readfile(file)
    local f 		= assert(io.open(file, "rb"))
    local content	= f:read("*all")
    f:close()
    return content
end

local Stream 		= require 'eonz.lexer.stream'
local Context 		= require 'eonz.lexer.context'
local info		= require 'eonz.lexer.info'
local Source 		= info.Source
local lua_grammar	= require 'eonz.reflect.lua_grammar'
local LuaParser		= require 'eonz.reflect.lua_parser'

local target_roots	= {}
local targets 		= eonz.platform.capture("find ../src -name \"*.lua\""):split("\n")
local contracts 	= require('eonz.reflect.general-contracts')

for i, contract in ipairs(contracts) do
	tests["test contract: " .. contract.name] = function ()
		for j, target in ipairs(targets) do

			target_roots[j] = target_roots[j] or (LuaParser({
				source = Source {
					text = readfile(target),
					name = target
				},

				stream = { 'default' }
			}):chunk():link())

			local ast = target_roots[j]
			contract.invoke(ast)
			show_progress(j, #targets)
		end
	end
end
