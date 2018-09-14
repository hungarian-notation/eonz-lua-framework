return function (utils)
	local COMMENT_CLEANUP_PATTERN = "^[%-%s]*([^%-%s].*[^%-%s])[%-%s]*$"

	function utils.process_comment(comment)
		if comment:id('comment.line') then
			comment = comment:text():match(COMMENT_CLEANUP_PATTERN)
			comment = comment and string.trim(comment)
			return { comment or "" }
		elseif comment:id('comment.multiline') then
			local 	inner = comment:text():sub(comment:captures(2) - (comment:start() - 1), comment:captures(3) - (comment:start()))
				inner = inner:match(COMMENT_CLEANUP_PATTERN)
				inner = string.split(inner, "[\r]?[\n]")
			for i, str in ipairs(inner) do
				inner[i] = string.trim(str) or ""
			end
			return 	inner
		end
	end

	function utils.process_comment_tokens(raw)
		local lines	= {}
		local processed = {}
		local function finish_line()
			if #processed > 0 then
				table.insert(lines, table.concat(processed, " "))
				processed = {}
			end
		end
		for i, rc in ipairs(raw) do
			local next = utils.process_comment(rc)

			for j, part in ipairs(next) do
				if part == "" then
					finish_line()
				else
					table.insert(processed, part)
				end
			end
		end
		finish_line()
		return lines
	end

	function utils.collect_comments(node)
		local comments 		= {}
		local accept_newline	= true
		local accept_blanks	= true
		local search 		= node:start()

		while search:adjacent(-1, { 'default', 'newlines', 'comments' }) do
			search = search:adjacent(-1)

			if search and search:channels{ 'newlines' } then
				if accept_newline then
					accept_newline = false
			 	elseif accept_blanks then
					accept_blanks = false
				else
					break
				end

			elseif search and search:channels{ 'comments' } then
				table.insert(comments, 1, search)
				accept_newline 	= true
				accept_blanks	= false
			else
				break
			end
		end

		return utils.process_comment_tokens(comments)
	end
end
