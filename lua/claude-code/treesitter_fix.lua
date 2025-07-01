local M = {}

-- Global treesitter error handler
local function safe_treesitter_call(func, ...)
	local ok, result = pcall(func, ...)
	if not ok then
		-- Silently ignore treesitter errors to prevent spam
		return nil
	end
	return result
end

-- Disable treesitter for specific buffer types
local function disable_treesitter_for_buffer(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local buftype = vim.bo[bufnr].buftype
	local filetype = vim.bo[bufnr].filetype

	-- Skip treesitter for terminal, nofile, and special buffers
	if buftype == "terminal" or buftype == "nofile" or filetype == "NvimTree" then
		vim.schedule(function()
			local ok, ts_highlight = pcall(require, "vim.treesitter.highlighter")
			if ok and ts_highlight.active[bufnr] then
				safe_treesitter_call(function()
					ts_highlight.active[bufnr]:destroy()
				end)
			end

			-- Also try to detach treesitter
			local ok2, ts = pcall(require, "vim.treesitter")
			if ok2 then
				safe_treesitter_call(function()
					ts.stop(bufnr)
				end)
			end
		end)
	end
end

-- Setup treesitter protection
function M.setup()
	-- Create autocmds to handle treesitter issues
	vim.api.nvim_create_augroup("ClaudeTreesitterFix", { clear = true })

	-- Disable treesitter for terminal and special buffers
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter", "TermOpen" }, {
		group = "ClaudeTreesitterFix",
		callback = function(args)
			disable_treesitter_for_buffer(args.buf)
		end,
	})

	-- Override treesitter error handling
	local original_on_error = vim.treesitter.highlighter.on_error
	if original_on_error then
		vim.treesitter.highlighter.on_error = function(...)
			-- Silently ignore treesitter errors
			return
		end
	end

	-- Patch nvim_buf_set_extmark to handle out of range errors
	local original_set_extmark = vim.api.nvim_buf_set_extmark
	vim.api.nvim_buf_set_extmark = function(bufnr, ns_id, line, col, opts)
		-- Validate parameters before calling
		if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		local line_count = vim.api.nvim_buf_line_count(bufnr)
		if line >= line_count then
			return
		end

		local line_text = vim.api.nvim_buf_get_lines(bufnr, line, line + 1, false)[1] or ""
		if col > #line_text then
			return
		end

		return safe_treesitter_call(original_set_extmark, bufnr, ns_id, line, col, opts)
	end
end

-- Disable treesitter for a specific buffer
function M.disable_for_buffer(bufnr)
	disable_treesitter_for_buffer(bufnr)
end

-- Safe treesitter function wrapper
function M.safe_call(func, ...)
	return safe_treesitter_call(func, ...)
end

return M
