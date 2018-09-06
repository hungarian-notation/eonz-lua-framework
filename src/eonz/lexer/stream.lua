local eonz 	= require "eonz"

local Stream = eonz.class "eonz::lexer::Stream"
do
	function Stream.new(opts)
		opts = eonz.options.from(opts)

		local list = opts.foreach
			or opts.each
			or opts.list
			or opts.array

		return setmetatable({
			_n 	= #list,
			_l	= list,
			_i	= 1
		}, Stream)
	end

	function Stream:clone()
		return setmetatable({
			_n 	= self._n,
			_l	= self._l,
			_i	= self._i,
		}, Stream)
	end

	function Stream:get(i)
		i = (i < 0) and (self:length() + i + 1) or (i)
		return self._l[i]
	end

	function Stream:look(i)
		i = (i <= 0) and (self._i + i) or (self._i + i - 1)
		return self._l[i]
	end

	function Stream:consume()
		self._i = self._i + 1
		return not self:eof()
	end

	function Stream:index()
		return self._i
	end

	function Stream:length()
		return self._n
	end

	function Stream:eof()
		return self:index() > self:length()
	end
end

return Stream
