local eonz 	= require 'eonz'

local utils 	= {}
do
	require 'eonz.reflect.analysis.comments' (utils)
	require 'eonz.reflect.analysis.scope' (utils)
end

return utils
