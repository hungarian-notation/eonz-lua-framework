local eonz 		= require 'eonz'
local table 		= eonz.pf.table
local string		= eonz.pf.string

local Production 	= require 'eonz.lexer.production'

local Grammar = eonz.class "eonz::lexer::Grammar"
do
	function Grammar.new(productions, opt)
		for i, prod in ipairs(productions) do
			if getmetatable(prod) ~= Production then
				local id, alts, opt = eonz.table.unpack(prod)

				-- use any key-value pairs defined directly in
				-- the production table as arguments to the
				-- production options table

				opt = table.merge({}, prod, opt or {})
				for i in ipairs(prod) do opt[i] = nil end

				productions[i] = Production(id, alts, opt)
			end
		end

		return setmetatable({
			_productions = productions or {}
		}, Grammar)
	end

	function Grammar:production_for(id)
		for i, prod in ipairs(self:productions()) do
			if prod:id(id) then
				return prod
			end
		end

		return nil
	end

	function Grammar:productions()
		return self._productions
	end

	function Grammar:add(production)
		table.insert(self._productions, production)
	end
end

return Grammar
