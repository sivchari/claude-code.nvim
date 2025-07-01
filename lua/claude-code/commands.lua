local M = {}

-- Open Claude in right pane
function M.open_in_right_pane()
	local terminal = require("claude-code.terminal")

	-- Split right if not already in split
	local current_win = vim.api.nvim_get_current_win()

	-- Check if we're in a split layout already
	local wins = vim.api.nvim_list_wins()
	for _, win in ipairs(wins) do
		if win ~= current_win then
			local buf = vim.api.nvim_win_get_buf(win)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			if buf_name:match("Claude") then
				-- Already have Claude in a split, focus it
				vim.api.nvim_set_current_win(win)
				return
			end
		end
	end

	-- Create vertical split on the right
	vim.cmd("vsplit")
	vim.cmd("wincmd l") -- Move to right window

	-- Get current session info
	local worktree_path = vim.fn.getcwd()
	local session_name = vim.fn.fnamemodify(worktree_path, ":t")

	-- Create terminal buffer in the split
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buflisted = false
	vim.api.nvim_win_set_buf(0, buf)

	-- Start terminal with claude command
	local job_id = vim.fn.termopen("claude", {
		on_exit = function(_, exit_code)
			-- Keep window open even if claude exits
		end,
	})

	if job_id > 0 then
		vim.api.nvim_buf_set_name(buf, "Claude Code")

		-- Set buffer options
		vim.bo[buf].filetype = ""
		vim.bo[buf].syntax = "off"

		-- Use treesitter fix
		local treesitter_fix = require("claude-code.treesitter_fix")
		treesitter_fix.disable_for_buffer(buf)

		-- Set keymaps
		vim.api.nvim_buf_set_keymap(
			buf,
			"t",
			"<C-q>",
			"<C-\\><C-n><C-w>h",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<C-w>h", { noremap = true, silent = true })

		-- Enter insert mode
		vim.cmd("startinsert")

		vim.notify("Claude Code opened in right pane", vim.log.levels.INFO)
	else
		vim.notify("Failed to start Claude Code", vim.log.levels.ERROR)
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

return M
