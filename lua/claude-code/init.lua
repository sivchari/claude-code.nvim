local M = {}

-- Default configuration
M.config = {
	width = 0.5, -- 50% of the window width
	height = 1, -- Full height
	position = "right",
	cmd = "claude",
	mappings = {
		toggle = "<leader>cc",
	},
	auto_scroll = true,
	start_in_insert = true,
}

-- Setup function
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	local commands = require("claude-code.commands")
	local worktree = require("claude-code.worktree")
	local terminal = require("claude-code.terminal")
	local treesitter_fix = require("claude-code.treesitter_fix")
	local nvim_tree_ext = require("claude-code.nvim_tree_extension")

	-- Setup components (treesitter fix first)
	treesitter_fix.setup()
	terminal.setup()
	nvim_tree_ext.setup()

	-- Create user commands
	vim.api.nvim_create_user_command("Claude", function()
		commands.open_in_right_pane()
	end, {})

	-- Git worktree commands

	vim.api.nvim_create_user_command("ClaudeWorktreeCreate", function(opts)
		local branch = opts.args
		if branch == "" then
			vim.ui.input({ prompt = "Branch name: " }, function(input)
				if input and input ~= "" then
					worktree.create_worktree(input)
				end
			end)
		else
			worktree.create_worktree(branch)
		end
	end, { nargs = "?" })

	vim.api.nvim_create_user_command("ClaudeWorktreeSwitch", function()
		worktree.pick_worktree(function(wt, path)
			worktree.switch_to_worktree(path)
		end)
	end, {})

	vim.api.nvim_create_user_command("ClaudeWorktreeRemove", function()
		worktree.pick_worktree(function(wt, path)
			local current_path = vim.fn.getcwd()
			if path == current_path then
				vim.notify("Cannot remove current worktree", vim.log.levels.WARN)
				return
			end
			worktree.remove_worktree(path)
		end)
	end, {})

	-- Claude sessions status command
	vim.api.nvim_create_user_command("ClaudeSessions", function()
		terminal.show_sessions_status()
	end, {})

	-- Claude monitor command
	vim.api.nvim_create_user_command("ClaudeMonitor", function()
		terminal.toggle_monitor()
	end, {})

	-- Set up key mappings
	if M.config.mappings.toggle then
		vim.keymap.set("n", M.config.mappings.toggle, function()
			local ok, err = pcall(M.toggle)
			if not ok then
				vim.notify("Claude toggle error: " .. tostring(err), vim.log.levels.ERROR)
			end
		end, { desc = "Toggle Claude Code" })
	end

	-- Worktree and session keymaps
	vim.keymap.set("n", "<leader>cw", function()
		worktree.pick_worktree(function(wt, path)
			worktree.switch_to_worktree(path)
		end)
	end, { desc = "Switch worktree" })

	-- Sessions status
	vim.keymap.set("n", "<leader>cl", function()
		terminal.show_sessions_status()
	end, { desc = "Show Claude sessions status" })

	-- Claude monitor toggle
	vim.keymap.set("n", "<leader>cm", function()
		terminal.toggle_monitor()
	end, { desc = "Toggle Claude sessions monitor" })
end

-- Toggle Claude Code terminal (new architecture)
function M.toggle()
	local ok, terminal = pcall(require, "claude-code.terminal")
	if not ok then
		vim.notify("Failed to load terminal module: " .. tostring(terminal), vim.log.levels.ERROR)
		return
	end

	local ok, worktree = pcall(require, "claude-code.worktree")
	if not ok then
		vim.notify("Failed to load worktree module: " .. tostring(worktree), vim.log.levels.ERROR)
		return
	end

	-- Get current worktree context
	local current_path = vim.fn.getcwd()

	local ok, worktrees = pcall(worktree.list_worktrees)
	if not ok then
		worktrees = {}
	end

	local current_worktree = nil
	local best_match_length = 0

	for _, wt in ipairs(worktrees) do
		-- Check for exact match or if current path starts with worktree path
		if current_path == wt.path or current_path:find(wt.path, 1, true) == 1 then
			-- Prefer longer matches (more specific paths)
			if #wt.path > best_match_length then
				current_worktree = wt
				best_match_length = #wt.path
			end
		end
	end

	if current_worktree then
		local session_id = vim.fn.fnamemodify(current_path, ":t") -- Use current path for session name

		-- Check if we need to switch context even if terminal is visible
		local info = terminal.get_current_session()

		-- Priority 1: If Claude is running and visible, just keep it running
		if info.is_claude_running and info.is_visible then
			-- Claude is running and visible - only update working directory without killing session
			if info.current_path ~= current_path then
				-- Just change directory in the existing Claude session (gently)
				terminal.switch_context(info.session_id, current_path)
			end
			-- Don't toggle - terminal is already visible and focused
			return
		end

		-- Priority 2: If Claude is running but hidden, just show the existing session
		if info.is_claude_running and not info.is_visible then
			-- Show the existing Claude session without changing context
			terminal.show(info.session_id, info.current_path, false) -- no force_context_change
			return
		end

		-- Priority 3: Handle normal toggle/show for non-Claude or new sessions
		if not info.session_id or info.session_id ~= session_id or info.current_path ~= current_path then
			-- Only switch sessions when absolutely necessary
			if info.is_visible then
				-- If terminal is visible but different session/path, switch context
				terminal.switch_context(session_id, current_path)
			else
				-- If terminal is hidden, show it with context
				terminal.show(session_id, current_path, true)
			end
		else
			-- Same session, just toggle normally
			-- Clean any partial input before showing terminal
			if info.terminal_valid and not info.is_visible then
				-- Clear any partial input that might be in the terminal
				terminal.clear_input_line()
				vim.wait(50)
			end
			terminal.toggle(session_id, current_path)
		end
	else
		-- Fallback to simple terminal
		local info = terminal.get_current_session()

		-- If Claude is running, preserve it
		if info.is_claude_running then
			if info.is_visible then
				return -- Already visible, do nothing
			else
				terminal.show(info.session_id, info.current_path, false) -- Show existing session
				return
			end
		end

		if info.terminal_valid and not info.is_visible then
			terminal.clear_input_line()
			vim.wait(50)
		end
		terminal.toggle("default", current_path)
	end
end

-- Open Claude Code (delegated to terminal module)
function M.open()
	local terminal = require("claude-code.terminal")
	local worktree = require("claude-code.worktree")

	-- First check if Claude terminal is already visible
	local info = terminal.get_current_session()
	if info.is_visible then
		-- Just focus the existing terminal
		return
	end

	-- Get current worktree context
	local current_path = vim.fn.getcwd()
	local worktrees = worktree.list_worktrees()
	local current_worktree = nil

	for _, wt in ipairs(worktrees) do
		if current_path:find(wt.path, 1, true) == 1 then
			current_worktree = wt
			break
		end
	end

	if current_worktree then
		local session_id = vim.fn.fnamemodify(current_path, ":t") -- Use current path for session name
		terminal.show(session_id, current_path) -- Use current path instead of worktree.path
		terminal.start_claude(session_id, current_path) -- Use current path instead of worktree.path
	else
		-- Fallback to simple terminal
		terminal.show("default", current_path)
		terminal.start_claude("default", current_path)
	end
end

return M
