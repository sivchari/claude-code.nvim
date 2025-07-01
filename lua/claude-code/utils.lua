local M = {}

-- Get visual selection text
function M.get_visual_selection()
	local s_start = vim.fn.getpos("'<")
	local s_end = vim.fn.getpos("'>")
	local n_lines = math.abs(s_end[2] - s_start[2]) + 1
	local lines = vim.api.nvim_buf_get_lines(0, s_start[2] - 1, s_end[2], false)

	if n_lines == 1 then
		lines[1] = string.sub(lines[1], s_start[3], s_end[3])
	else
		lines[1] = string.sub(lines[1], s_start[3])
		lines[n_lines] = string.sub(lines[n_lines], 1, s_end[3])
	end

	return table.concat(lines, "\n")
end

-- Get current file info
function M.get_current_file_info()
	local filepath = vim.fn.expand("%:p")
	local filename = vim.fn.expand("%:t")
	local filetype = vim.bo.filetype

	return {
		path = filepath,
		name = filename,
		type = filetype,
	}
end

-- Format file content for Claude
function M.format_file_content(content, file_info)
	local formatted = string.format(
		"File: %s\nType: %s\n```%s\n%s\n```",
		file_info.path,
		file_info.type,
		file_info.type,
		content
	)
	return formatted
end

-- Get git root directory
function M.get_git_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
	if vim.v.shell_error == 0 then
		return vim.fn.trim(git_root)
	end
	return nil
end

-- Get project context
function M.get_project_context()
	local context = {}
	local git_root = M.get_git_root()

	if git_root then
		context.project_root = git_root
		context.git_status = vim.fn.system("cd " .. git_root .. " && git status --short")
	else
		context.project_root = vim.fn.getcwd()
	end

	return context
end

return M
