local eonz = require 'eonz'

local Source = eonz.class {
	name 	= 'eonz::lexer::info::Source'
}

local SourceInterval = eonz.class {
	name 	= 'eonz::lexer::info::SourceInterval'
}

local SourceLine = eonz.class {
	name 	= 'eonz::lexer::info::SourceLine',
	extends	= SourceInterval
}

local SourcePosition = eonz.class {
	name 	= 'eonz::lexer::info::SourcePosition'
}

do -- Source
	function Source:__init(opt)
		opt = eonz.options.from(opt)
		self._text	= opt.text
		self._name	= opt.name or 'unknown-source'
		self._lang	= opt.lang or 'unknwon-language'
		self._lines	= nil -- lazily created
	end

	function Source:text()
		return self._text
	end

	function Source:len(...)
		return self:text():len(...)
	end

	function Source:sub(...)
		return self:text():sub(...)
	end

	function Source:name()
		return self._name
	end

	function Source:lang()
		return self._lang
	end

	local function init_lines(self)
		local lines 	= {}
		local cursor 	= 1
		local text 	= self._text

		while cursor < string.len(text) do
			local n, nx = text:find("[\r]?[\n]", cursor)
			n 	= n or string.len(text) + 1
			nx 	= nx or n + 1

			local line_info = SourceLine {
				index		= #lines + 1,
				start		= cursor,
				stop		= n,
				source		= self,
			}

			lines[line_info:index()] = line_info

			cursor = nx + 1
		end

		self._lines = lines
	end

	function Source:lines()
		if not self._lines then
			init_lines(self)
		end

		return self._lines
	end

	function Source:line_at(i)
		local lines = self:lines()

		for j = 1, #lines do
			if lines[j]:stop() > i then
				--print(string.format("offset %d on line %d which runs from %d to %d",
				--	i, j, lines[j].interval:start(), lines[j].interval:stop()))
				return lines[j]
			end
		end

		return nil
	end

	function Source:line_number_at(i)
		local info = self:line_at(i)
		return info and info:index() or nil
	end
end

do -- SourcePosition
	function SourcePosition:__init(opt)
		opt = eonz.options.from(opt)
		self._offset 	= opt:checknumber 'offset'
		self._source	= opt:checktable 'source'
		self._line	= nil -- lazily evaluated
	end

	function SourcePosition:line_info()
		if not self._line then
			self._line = self:source():line_at(self:offset())
		end

		return self._line
	end

	function SourcePosition:line()
		return not self:line_info() and -1 or
			(self:line_info():index())
	end

	function SourcePosition:position()
		return not self:line_info() and -1 or
			(self:offset() - self:line_info():start() + 1)
	end

	function SourcePosition:offset()
		return self._offset
	end

	function SourcePosition:source()
		return self._source
	end

	function SourcePosition:__tostring(short)
		if short then
			return string.format("%s:%s", self:line(), self:position())
		else
			return string.format("%s:%s:%s", self:source():name(), self:line(), self:position())
		end
	end

	SourcePosition.tostring = SourcePosition.__tostring
end

do -- SourceInterval
	function SourceInterval:__init(opt)
		SourceInterval:__super { self, opt }
		opt = eonz.options.from(opt)
		self._start	= opt:checknumber 'start'
		self._stop	= opt:checknumber 'stop'
		self._source 	= opt.source
		self._context	= opt.context
	end

	function SourceInterval:start()
		return self._start
	end

	function SourceInterval:stop()
		return self._stop
	end

	function SourceInterval:start_position()
		return SourcePosition { offset = self:start(), source = self:source() }
	end

	function SourceInterval:stop_position()
		return SourcePosition { offset = self:stop(), source = self:source() }
	end

	function SourceInterval:context()
		return self._context
	end

	function SourceInterval:source()
		return self._source
			or self:context() and self:context():source()
	end

	function SourceInterval:text()
		return self:source():text():sub(self:start(), self:stop())
	end

	function SourceInterval:__tostring()
		return "(" .. self:start_position():tostring() .. ", " .. self:stop_position():tostring() .. "]"
	end
end

do -- SourceLine
	function SourceLine:__init(opt)
		opt = eonz.options.from(opt)
		SourceLine:__super { self, opt }
		self._line = opt.line or opt.index
	end

	--function SourceLine.interval()
	--	return self
	--end

	function SourceLine:number()
		return self._line
	end

	function SourceLine:tostring()
		return string.format("%s:%s", self:source():name(), self:number())
	end

	SourceLine.line 	= SourceLine.number
	SourceLine.line_number 	= SourceLine.number
	SourceLine.index 	= SourceLine.number
	SourceLine.__tostring	= SourceLine.tostring
end

return {
	Source		= Source,
	SourceInterval 	= SourceInterval,
	SourceLine	= SourceLine,
	SourcePosition	= SourcePosition
}
