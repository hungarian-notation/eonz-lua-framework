return function(file)
	if not io then error('io package is not present') end
	if not io.open then error('io.open is not present') end
   	local f 		= assert(io.open(file, "rb"))
   	local content		= f:read("*all")
   	f:close()
   	return content
end
