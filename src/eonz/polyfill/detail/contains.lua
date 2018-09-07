local index_of_impl = require 'eonz.polyfill.detail.index_of'

return function (t, item)
	return index_of_impl(t, item) ~= nil
end
