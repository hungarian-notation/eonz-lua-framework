return function (t, item)
	for i, value in ipairs(t) do
		if value == item then
			return i
		end
	end

	return nil
end
