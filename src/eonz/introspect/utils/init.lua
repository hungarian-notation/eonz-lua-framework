local eonz 	= require "eonz"

local utils 	= {}
do
	require "eonz.introspect.utils.comments" (utils)
	require "eonz.introspect.utils.scope" (utils)
end

return utils
