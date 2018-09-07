local eonz 	= require 'eonz'

local Stream = eonz.class "eonz::lexer::Stream"
do
	function Stream.new(list)
		return setmetatable({
			_l	= assert(list),
			_i	= 1
		}, Stream)
	end

	function Stream:clone()
		return setmetatable({
			_l	= assert(self._l),
			_i	= self._i,
		}, Stream)
	end

	function Stream:list(i)
		assert(assert(self,"self was nil")._l, "self._l was nil")
		return self._l
	end

	function Stream:look(i)
		i = i or 1
		i = (i <= 0) and (self:index() + i) or (self:index() + i - 1)
		return assert(assert(self,"self was nil"):list(),"self:list() returned nil")[assert(i,"i was nil")]
	end

	function Stream:consume()
		local consumed = self:look()
		self:index(self:index() + 1)
		return consumed
	end

	function Stream:index(set)
		if set then
			self._i = set
		end
		return self._i
	end

	function Stream:length()
		return #(self:list())
	end

	function Stream:eof()
		return self:index() > self:length()
	end
end

return Stream
