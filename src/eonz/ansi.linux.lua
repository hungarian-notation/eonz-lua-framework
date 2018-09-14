local pf 	= require 'eonz.polyfill'
local ansi 	= {}

local ESCAPE_CHAR = string.char(27)
local ESCAPE_CSI  = ESCAPE_CHAR .. "["

function ansi.csi(...)
  return pf.string.join(ESCAPE_CSI, pf.string.join(...))
end

function ansi.move_up(n) 	return ansi.csi(n, 'A') end
function ansi.move_down(n) 	return ansi.csi(n, 'B') end
function ansi.move_right(n) 	return ansi.csi(n, 'C') end
function ansi.move_left(n) 	return ansi.csi(n, 'D') end

function ansi.move_cursor(x, y)
	local bf = pf.string.builder()

	if x and x < 0 then
		bf:append(ansi.move_left(-x))
	elseif x and x > 0  then
		bf:append(ansi.move_right(x))
	end

	if y and y < 0 then
		bf:append(ansi.move_up(-y))
	elseif y and y > 0  then
		bf:append(ansi.move_down(y))
	end

	return tostring(bf)
end

function ansi.show_cursor(show)
	return ansi.csi(show and "?25h" or "?25l")
end

function ansi.scroll(rows)
	return ansi.csi(rows < 0 and (tostring(-rows) .. "T") or (tostring(rows) .. "S"))
end

function ansi.cursor_column(x)
	return ansi.csi(x, 'G')
end

function ansi.sgr(...)
  return ansi.csi(pf.string.join(...), "m")
end

function ansi.ansi_color_4bit(field, index)
  local value = index

  if index < 8 then
    value = value + 30
  else
    value = value - 8 + 90
  end

  if field ~= "foreground" then
    value = value + 10
  end

  return ansi.sgr(value)
end

function ansi.ansi_color_8bit(field, index)
  return ansi.sgr(field == "foreground" and 38 or 48, ";5;", args[1])
end

function ansi.ansi_color_256bit(field, r, g, b)
    return ansi.sgr(field == "foreground" and 38 or 48, ";2;", r, ";", g, ";", b)
end

function ansi.color(field, ...)
  local args = {...}

  if #args == 1 and type(args[1]) == 'table' then
    args = args[1]
  end

  if #args == 1 and args[1] < 16 then
    return ansi.ansi_color_4bit(field, args[1])
  elseif #args == 1 and args[1] >= 16 then
    return ansi.ansi_color_8bit(field, args[1])
  elseif #args == 3 then
    return ansi.ansi_color_256bit(field, args[1], args[2], args[3])
  end
end

function ansi.fg(...)
  return ansi.color("foreground", ...)
end

function ansi.bg(...)
  return ansi.color("background", ...)
end

function ansi.reset()
  return ansi.sgr(0)
end

function ansi.apply(style)
  if type(style) ~= 'table' then
    style = {}
  end

  local bf = ""

  bf = bf .. (ansi.reset())

  local fg = style.fg or style.fore or style.foreground or style.color or nil
  local bg = style.bg or style.back or style.background or nil

  if fg then
    bf = bf .. (ansi.fg(fg))
  end

  if bg then
    bf = bf .. (ansi.bg(bg))
  end

  if style.bold then
    bf = bf .. (ansi.sgr(1))
  end

  if style.italic then
    bf = bf .. (ansi.sgr(3))
  end

  if style.underline then
    bf = bf .. (ansi.sgr(4))
  end

  return tostring(bf)
end

function ansi.style(style, ...)
  return ansi.apply(style) .. pf.string.join(...) .. ansi.apply()
end

return ansi
