local M = {}

-- Session-based terminal state
M.sessions = {} -- { [session_id] = { terminal_buf, terminal_job_id, current_path, ... } }

M.state = {
	terminal_win = nil, -- Shared window (only one visible at a time)
	current_session_id = nil, -- Currently active session
	is_visible = false,
}

-- Monitor state
M.monitor = {
	win = nil,
	buf = nil,
	timer = nil,
	is_visible = false,
	refresh_interval = 2000, -- 2 seconds
}

-- Configuration
M.config = {
	shell = vim.o.shell,
	size = {
		width = 0.8, -- 80% of screen width
		height = 0.8, -- 80% of screen height
	},
	position = {
		row = 0.1, -- 10% from top
		col = 0.1, -- 10% from left
	},
	border = "rounded",
	title = "Claude Terminal",
	close_on_exit = false,
}

-- Get or create session data
local function get_or_create_session(session_id)
	if not session_id then
		session_id = "default"
	end

	if not M.sessions[session_id] then
		M.sessions[session_id] = {
			terminal_buf = nil,
			terminal_job_id = nil,
			current_path = nil,
		}
	end

	return M.sessions[session_id]
end

-- Create or get session-specific terminal buffer
local function get_or_create_terminal(session_id)
	local session = get_or_create_session(session_id)

	-- Check if existing terminal is still valid
	if session.terminal_buf and vim.api.nvim_buf_is_valid(session.terminal_buf) then
		local buf_name = vim.api.nvim_buf_get_name(session.terminal_buf)
		if vim.bo[session.terminal_buf].buftype == "terminal" and buf_name:match("Claude") then
			return session.terminal_buf, false -- existing terminal
		end
	end

	-- Create new terminal buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buflisted = false

	-- Create a temporary window for terminal creation (we'll close it later)
	local temp_win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = 1,
		height = 1,
		row = 0,
		col = 0,
		style = "minimal",
		noautocmd = true,
	})

	-- Save current window
	local current_win = vim.api.nvim_get_current_win()

	-- Switch to temp window and create terminal
	vim.api.nvim_set_current_win(temp_win)
	local job_id = vim.fn.termopen(M.config.shell, {
		on_exit = function(_, exit_code)
			-- Always hide terminal when shell exits (including when Claude CLI exits)
			vim.schedule(function()
				M.hide()
				-- Clean up the session if it was terminated
				if session then
					session.terminal_buf = nil
					session.terminal_job_id = nil
				end
			end)
		end,
	})

	-- Restore original window
	vim.api.nvim_set_current_win(current_win)

	-- Close temp window
	vim.api.nvim_win_close(temp_win, true)

	if job_id > 0 then
		session.terminal_buf = buf
		session.terminal_job_id = job_id
		vim.api.nvim_buf_set_name(buf, "Claude Terminal - " .. session_id)

		-- Set buffer options to prevent treesitter issues
		vim.bo[buf].filetype = "" -- Clear filetype to prevent treesitter
		vim.bo[buf].syntax = "off" -- Disable syntax highlighting

		-- Use the treesitter fix module
		local treesitter_fix = require("claude-code.treesitter_fix")
		treesitter_fix.disable_for_buffer(buf)

		-- Set terminal-specific keymaps
		vim.api.nvim_buf_set_keymap(
			buf,
			"t",
			"<C-q>",
			"<C-\\><C-n>:lua require('claude-code.terminal').hide()<CR>",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"<Esc>",
			":lua require('claude-code.terminal').hide()<CR>",
			{ noremap = true, silent = true }
		)
		vim.api.nvim_buf_set_keymap(
			buf,
			"n",
			"q",
			":lua require('claude-code.terminal').hide()<CR>",
			{ noremap = true, silent = true }
		)

		-- Add enhanced exit handling for common exit patterns
		local exit_commands = { "exit", "/exit", "quit", "/quit" }
		for _, cmd in ipairs(exit_commands) do
			vim.api.nvim_buf_set_keymap(
				buf,
				"t",
				cmd .. "<CR>",
				cmd
					.. "<CR><cmd>lua vim.defer_fn(function() require('claude-code.terminal').check_and_close_if_exited('"
					.. session_id
					.. "') end, 1000)<CR>",
				{ noremap = true, silent = true }
			)
		end

		-- Monitor terminal output for Claude exit
		vim.api.nvim_create_autocmd("TermClose", {
			buffer = buf,
			callback = function()
				-- Terminal process ended, hide the modal
				vim.schedule(function()
					if M.state.is_visible then
						M.hide()
					end
				end)
			end,
		})

		-- Also monitor text changes for exit detection
		local exit_timer = nil
		vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
			buffer = buf,
			callback = function()
				-- Debounce the exit check
				if exit_timer then
					vim.fn.timer_stop(exit_timer)
				end
				exit_timer = vim.fn.timer_start(200, function()
					M.check_for_claude_exit(session_id)
				end)
			end,
		})

		return buf, true -- new terminal
	else
		vim.api.nvim_buf_delete(buf, { force = true })
		return nil, false
	end
end

-- Create floating window for terminal
local function create_floating_window(buf)
	local width = math.floor(vim.o.columns * M.config.size.width)
	local height = math.floor(vim.o.lines * M.config.size.height)
	local row = math.floor(vim.o.lines * M.config.position.row)
	local col = math.floor(vim.o.columns * M.config.position.col)

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = M.config.border,
		title = M.config.title,
		title_pos = "center",
		style = "minimal",
	}

	local win = vim.api.nvim_open_win(buf, true, win_config)

	-- Set window options
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].wrap = false
	vim.wo[win].spell = false
	vim.wo[win].list = false

	return win
end

-- Switch terminal context to a specific worktree/session
function M.switch_context(session_id, worktree_path)
	local session = get_or_create_session(session_id)

	if not session.terminal_buf or not vim.api.nvim_buf_is_valid(session.terminal_buf) then
		return false
	end

	if not session.terminal_job_id then
		vim.notify("Terminal job not available", vim.log.levels.WARN)
		return false
	end

	-- First ensure we're in normal mode in the terminal and clear any partial input
	M.send_control_char(session_id, 3) -- Ctrl-C to break any running command
	vim.wait(100)
	M.clear_input_line(session_id) -- Ctrl-U to clear current line
	vim.wait(50)

	-- Send cd command silently, then clear screen
	M.send_command_silent(string.format("cd %s", vim.fn.shellescape(worktree_path)), session_id)
	vim.wait(100)
	M.send_command("clear", session_id)

	session.current_path = worktree_path

	-- Update title to show current session
	if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
		local title = string.format("Claude Terminal - %s", session_id)
		vim.api.nvim_win_set_config(M.state.terminal_win, { title = title })
	end

	-- Trigger session update event
	vim.api.nvim_exec_autocmds("User", { pattern = "ClaudeSessionUpdate" })

	return true
end

-- Send command to terminal
function M.send_command(command, session_id)
	if not session_id then
		session_id = M.state.current_session_id
	end

	local session = get_or_create_session(session_id)
	if not session.terminal_buf or not vim.api.nvim_buf_is_valid(session.terminal_buf) then
		return false
	end

	if not session.terminal_job_id then
		return false
	end

	-- Check if this is an exit command - if so, schedule terminal closure
	local cmd_lower = command:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if cmd_lower == "exit" or cmd_lower == "/exit" then
		-- Schedule closure after a brief delay to allow command to execute
		vim.defer_fn(function()
			if M.state.current_session_id == session_id and M.state.is_visible then
				M.hide()
			end
		end, 500)
	end

	local ok, err = pcall(vim.fn.chansend, session.terminal_job_id, command .. "\n")
	if not ok then
		vim.notify(string.format("Failed to send command: %s", err), vim.log.levels.ERROR)
		return false
	end

	return true
end

-- Send raw control character to terminal
function M.send_control_char(session_id, char_code)
	if not session_id then
		session_id = M.state.current_session_id
	end

	local session = get_or_create_session(session_id)
	if not session.terminal_buf or not vim.api.nvim_buf_is_valid(session.terminal_buf) then
		return false
	end

	if not session.terminal_job_id then
		return false
	end

	local ok, err = pcall(vim.fn.chansend, session.terminal_job_id, string.char(char_code))
	if not ok then
		vim.notify(string.format("Failed to send control character: %s", err), vim.log.levels.ERROR)
		return false
	end

	return true
end

-- Clear current input line in terminal
function M.clear_input_line(session_id)
	return M.send_control_char(session_id, 21) -- Ctrl-U (ASCII 21)
end

-- Send command silently (without showing in prompt history)
function M.send_command_silent(command, session_id)
	if not session_id then
		session_id = M.state.current_session_id
	end

	local session = get_or_create_session(session_id)
	if not session.terminal_buf or not vim.api.nvim_buf_is_valid(session.terminal_buf) then
		return false
	end

	if not session.terminal_job_id then
		return false
	end

	-- Clear any existing input first
	M.clear_input_line(session_id)
	vim.wait(50)

	-- Send the command silently
	local ok, err = pcall(vim.fn.chansend, session.terminal_job_id, command .. "\n")
	if not ok then
		vim.notify(string.format("Failed to send silent command: %s", err), vim.log.levels.ERROR)
		return false
	end

	-- Wait for command to execute, then clear the line from history
	vim.wait(200)
	M.send_control_char(session_id, 12) -- Ctrl-L to clear screen (optional)

	return true
end

-- Start Claude CLI for current session
function M.start_claude(session_id, worktree_path)
	if not M.switch_context(session_id, worktree_path) then
		return false
	end

	-- Ensure we're in the correct directory before starting claude (silently)
	if worktree_path then
		M.send_command_silent(string.format("cd %s", vim.fn.shellescape(worktree_path)), session_id)
		vim.wait(100)
	end

	-- Send Claude CLI command
	local claude_cmd = "claude"
	M.send_command(claude_cmd, session_id)

	-- Trigger session update event
	vim.api.nvim_exec_autocmds("User", { pattern = "ClaudeSessionUpdate" })

	return true
end

-- Show terminal
function M.show(session_id, worktree_path, force_context_change)
	if not session_id then
		session_id = "default"
	end

	local buf, is_new_terminal = get_or_create_terminal(session_id)
	if not buf then
		vim.notify("Failed to create terminal", vim.log.levels.ERROR)
		return false
	end

	local session = get_or_create_session(session_id)

	-- If terminal window is already visible
	if
		M.state.is_visible
		and M.state.terminal_win
		and vim.api.nvim_win_is_valid(M.state.terminal_win)
	then
		-- Check if we need to switch to a different session
		if M.state.current_session_id ~= session_id then
			-- Switch to different session buffer in the same window
			vim.api.nvim_win_set_buf(M.state.terminal_win, buf)
			M.state.current_session_id = session_id

			-- Update window title
			local title = string.format("Claude Terminal - %s", session_id)
			vim.api.nvim_win_set_config(M.state.terminal_win, { title = title })
		end

		vim.api.nvim_set_current_win(M.state.terminal_win)
		return true
	end

	-- Clear any partial input before showing terminal (if terminal exists)
	if session.terminal_job_id then
		M.clear_input_line(session_id)
		vim.wait(50)
	end

	-- Create floating window
	local win = create_floating_window(buf)
	if not win then
		vim.notify("Failed to create terminal window", vim.log.levels.ERROR)
		return false
	end

	M.state.terminal_win = win
	M.state.is_visible = true
	M.state.current_session_id = session_id

	-- Only setup context and start claude for new terminals or when session changes
	local old_path = session.current_path

	if
		is_new_terminal
		or force_context_change
		or (session_id and worktree_path and old_path ~= worktree_path)
	then
		-- Set path after comparison
		if worktree_path then
			session.current_path = worktree_path
		end
		if session_id and worktree_path then
			-- Small delay to ensure terminal is ready
			vim.defer_fn(function()
				M.switch_context(session_id, worktree_path)
				-- Auto-start claude after context switch with directory verification
				vim.defer_fn(function()
					-- Ensure we're in the correct directory before starting claude (silently)
					M.send_command_silent(string.format("cd %s", vim.fn.shellescape(worktree_path)), session_id)
					vim.wait(100)
					M.send_command("claude", session_id)
				end, 500)
			end, 100)
		else
			-- Auto-start claude if no specific context
			vim.defer_fn(function()
				M.send_command("claude", session_id)
			end, 300)
		end
	else
		-- Set path even if no context change
		if worktree_path then
			session.current_path = worktree_path
		end
	end

	-- Enter insert mode in terminal
	vim.cmd("startinsert")

	return true
end

-- Hide terminal (keeps Claude running in background)
function M.hide()
	if M.state.terminal_win and vim.api.nvim_win_is_valid(M.state.terminal_win) then
		vim.api.nvim_win_close(M.state.terminal_win, false)
	end

	M.state.terminal_win = nil
	M.state.is_visible = false
	-- Note: terminal_buf and terminal_job_id are kept alive
end

-- Toggle terminal visibility
function M.toggle(session_id, worktree_path)
	if M.state.is_visible then
		M.hide()
	else
		M.show(session_id, worktree_path)
	end
end

-- Get Claude CLI status - returns detailed status information
function M.get_claude_status(session_id)
	if not session_id then
		session_id = M.state.current_session_id
	end

	local session = session_id and M.sessions[session_id]
	if
		not session
		or not session.terminal_buf
		or not vim.api.nvim_buf_is_valid(session.terminal_buf)
	then
		return "none" -- No session
	end

	if not session.terminal_job_id then
		return "none"
	end

	-- Get terminal buffer lines - check last 30 lines for better detection (like ccmanager)
	local ok, lines = pcall(vim.api.nvim_buf_get_lines, session.terminal_buf, -30, -1, false)
	if not ok then
		return "none"
	end

	local has_claude_content = false
	local is_waiting_for_input = false
	local is_busy = false

	-- Analyze terminal content (reverse order to check most recent first)
	for i = #lines, 1, -1 do
		local line = lines[i]:lower()

		-- Check for shell prompt patterns - if found, Claude is not running
		if
			line:match("^%s*[%w%-%.]+[@:][%w%-%.]*[%$%%#]%s*$") -- user@host$ or user@host%
			or line:match("%$%s*$")
			or line:match("%%%s*$") -- plain $ or %
			or line:match("^%s*%$%s*$")
			or line:match("^%s*%%%s*$")
		then -- standalone $ or %
			return "ready" -- Terminal ready but Claude not active
		end

		-- Claude busy state (ccmanager pattern)
		if line:match("esc to interrupt") then
			is_busy = true
			has_claude_content = true
		end

		-- Claude waiting for input patterns (ccmanager inspired)
		if
			line:match("│ do you want")
			or line:match("│ would you like")
			or line:match("do you want")
			or line:match("would you like")
			or line:match("press enter")
			or line:match("continue%?")
			or line:match("│.*%?%s*$") -- Questions ending with ?
		then
			is_waiting_for_input = true
			has_claude_content = true
		end

		-- Claude active patterns
		if line:match("claude") then
			-- Look for Claude CLI specific indicators
			if
				line:match("claude>") -- Claude prompt
				or line:match("claude %[") -- Claude with context
				or line:match("welcome.*claude") -- Welcome message
				or line:match("conversation with claude") -- Conversation mode
				or line:match("type.*exit.*to quit") -- Exit instruction
				or line:match("claude.*cli")
			then -- Claude CLI mention
				has_claude_content = true
				-- Check if we're at a prompt waiting for input
				if line:match("claude>%s*$") then
					is_waiting_for_input = true
				end
			end
		end

		-- Look for thinking/processing indicators
		if
			line:match("thinking%.%.%.")
			or line:match("processing%.%.%.")
			or line:match("█")
			or line:match("▌") -- Cursor or processing indicators
			or line:match("generating")
		then
			is_busy = true
			has_claude_content = true
		end
	end

	-- Return status based on what we found
	if not has_claude_content or M._has_recent_shell_prompt(lines) then
		return "ready" -- Terminal ready but Claude not active
	elseif is_waiting_for_input then
		return "waiting" -- Claude waiting for user input
	elseif is_busy or has_claude_content then
		return "running" -- Claude processing/thinking
	else
		return "ready" -- Default to ready state
	end
end

-- Backward compatibility: keep is_claude_running function
function M.is_claude_running(session_id)
	local status = M.get_claude_status(session_id)
	return status == "running" or status == "waiting"
end

-- Helper function to detect recent shell prompts
function M._has_recent_shell_prompt(lines)
	-- Check the last 3 lines for shell prompts
	for i = math.max(1, #lines - 2), #lines do
		local line = lines[i]:lower()
		if
			line:match("^%s*[%w%-%.]+[@:][%w%-%.]*[%$%%#]%s*$")
			or line:match("%$%s*$")
			or line:match("%%%s*$")
		then
			return true
		end
	end
	return false
end

-- Check for Claude exit and close terminal if detected
function M.check_for_claude_exit(session_id)
	if not session_id then
		session_id = M.state.current_session_id
	end

	local session = session_id and M.sessions[session_id]
	if
		not session
		or not session.terminal_buf
		or not vim.api.nvim_buf_is_valid(session.terminal_buf)
	then
		return
	end

	-- Get last 10 lines to check for exit patterns
	local ok, lines = pcall(vim.api.nvim_buf_get_lines, session.terminal_buf, -10, -1, false)
	if not ok then
		return
	end

	local found_exit_pattern = false
	local found_shell_prompt = false

	-- Check for Claude exit and shell prompt patterns
	for i = #lines, math.max(1, #lines - 5), -1 do
		local line = lines[i]
		local line_lower = line:lower()

		-- Check for shell prompt (indicating Claude has exited)
		if
			line_lower:match("^%s*[%w%-%.]*[@:].*[%$%%]%s*$") -- user@host$ or user@host%
			or line_lower:match("[%$%%]%s*$")
		then -- ends with $ or %
			found_shell_prompt = true
		end

		-- Check for Claude exit messages or goodbye patterns
		if
			line_lower:match("goodbye")
			or line_lower:match("see you")
			or line_lower:match("bye")
			or line_lower:match("thanks")
			or line_lower:match("until next time")
		then
			found_exit_pattern = true
		end
	end

	-- If we found both an exit pattern and shell prompt, Claude has exited
	if found_shell_prompt then
		-- Check if Claude is no longer running
		if not M.is_claude_running(session_id) then
			-- Claude has definitely exited - close terminal
			vim.schedule(function()
				if M.state.current_session_id == session_id and M.state.is_visible then
					M.hide()
				end
			end)
		end
	end
end

-- Simplified exit check function for direct calls
function M.check_and_close_if_exited(session_id)
	if not session_id then
		session_id = M.state.current_session_id
	end

	-- Simple check: if Claude is no longer running, close the terminal
	if not M.is_claude_running(session_id) then
		vim.schedule(function()
			if M.state.current_session_id == session_id and M.state.is_visible then
				M.hide()
			end
		end)
	end
end

-- Get current session info
function M.get_current_session()
	local current_session_id = M.state.current_session_id
	local session = current_session_id and M.sessions[current_session_id]

	return {
		session_id = current_session_id,
		current_path = session and session.current_path,
		is_visible = M.state.is_visible,
		is_claude_running = session and M.is_claude_running(current_session_id) or false,
		terminal_valid = session and session.terminal_buf and vim.api.nvim_buf_is_valid(
			session.terminal_buf
		) or false,
	}
end

-- Cleanup function
function M.cleanup()
	M.hide()
	M.hide_monitor() -- Close monitor on cleanup

	if M.state.terminal_buf and vim.api.nvim_buf_is_valid(M.state.terminal_buf) then
		vim.api.nvim_buf_delete(M.state.terminal_buf, { force = true })
	end

	M.state = {
		terminal_buf = nil,
		terminal_win = nil,
		terminal_job_id = nil,
		current_session = nil,
		is_visible = false,
	}
end

-- Show comprehensive session info for all worktrees
function M.show_sessions_status()
	local worktree = require("claude-code.worktree")
	local worktrees = worktree.list_worktrees()

	local lines = {
		"=== Claude Sessions Status ===",
	}

	-- Check each worktree for Claude session
	for _, wt in ipairs(worktrees) do
		local session_id = vim.fn.fnamemodify(wt.path, ":t")
		local session = M.sessions[session_id]
		local status_icon = "○" -- default: no session
		local status_text = "[no session]"

		if session and session.terminal_buf and vim.api.nvim_buf_is_valid(session.terminal_buf) then
			local claude_status = M.get_claude_status(session_id)

			if claude_status == "running" then
				status_icon = "●" -- Claude processing/thinking
				status_text = "[claude running]"
			elseif claude_status == "waiting" then
				status_icon = "◑" -- Claude waiting for user input
				status_text = "[waiting for input]"
			elseif claude_status == "ready" then
				status_icon = "◐" -- terminal exists but Claude not running
				status_text = "[terminal ready]"
			else
				status_icon = "○" -- no session
				status_text = "[no session]"
			end

			if M.state.current_session_id == session_id and M.state.is_visible then
				status_text = status_text .. " [visible]"
			end
		end

		table.insert(lines, string.format("%s %s (%s) %s", status_icon, session_id, wt.path, status_text))
	end

	table.insert(lines, "===============================")
	table.insert(
		lines,
		"● = Claude running, ◑ = Waiting for input, ◐ = Terminal ready, ○ = No session"
	)

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Show session info (for backward compatibility)
function M.show_info()
	M.show_sessions_status()
end

-- Create monitor buffer content
function M.create_monitor_content()
	local worktree = require("claude-code.worktree")
	local worktrees = worktree.list_worktrees()

	local lines = {
		"┌─ Claude Sessions ─┐",
	}

	-- Check each worktree for Claude session
	for _, wt in ipairs(worktrees) do
		local session_id = vim.fn.fnamemodify(wt.path, ":t")
		local session = M.sessions[session_id]
		local status_icon = "○" -- default: no session
		local branch_name = wt.branch or "detached"

		if session and session.terminal_buf and vim.api.nvim_buf_is_valid(session.terminal_buf) then
			local claude_status = M.get_claude_status(session_id)

			if claude_status == "running" then
				status_icon = "●" -- Claude processing/thinking
			elseif claude_status == "waiting" then
				status_icon = "◑" -- Claude waiting for user input
			elseif claude_status == "ready" then
				status_icon = "◐" -- terminal exists but Claude not running
			else
				status_icon = "○" -- no session
			end

			if M.state.current_session_id == session_id and M.state.is_visible then
				status_icon = status_icon .. "*" -- mark visible session
			end
		end

		-- Truncate long branch names
		if #branch_name > 12 then
			branch_name = branch_name:sub(1, 9) .. "..."
		end

		table.insert(lines, string.format("│ %s %-12s │", status_icon, branch_name))
	end

	table.insert(lines, "├─────────────────┤")
	table.insert(lines, "│ ● Running       │")
	table.insert(lines, "│ ◑ Waiting       │")
	table.insert(lines, "│ ◐ Ready         │")
	table.insert(lines, "│ ○ None          │")
	table.insert(lines, "│ * Visible       │")
	table.insert(lines, "└─────────────────┘")

	return lines
end

-- Update monitor content
function M.update_monitor()
	if not M.monitor.buf or not vim.api.nvim_buf_is_valid(M.monitor.buf) then
		return
	end

	local content = M.create_monitor_content()

	-- Update buffer content
	vim.api.nvim_buf_set_option(M.monitor.buf, "modifiable", true)
	vim.api.nvim_buf_set_lines(M.monitor.buf, 0, -1, false, content)
	vim.api.nvim_buf_set_option(M.monitor.buf, "modifiable", false)
end

-- Create monitor window
function M.create_monitor_window()
	-- Create buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_name(buf, "Claude Monitor")

	-- Calculate window dimensions
	local width = 19 -- Fixed width for the monitor
	local height = 12 -- Adjust based on content

	-- Calculate position (right side of screen)
	local ui = vim.api.nvim_list_uis()[1]
	local col = ui.width - width - 1
	local row = 2

	-- Create window
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "none",
		focusable = false,
	})

	-- Set window options
	vim.wo[win].wrap = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].cursorline = false

	-- Set buffer options
	vim.bo[buf].modifiable = false
	vim.bo[buf].readonly = true

	-- Store references
	M.monitor.buf = buf
	M.monitor.win = win

	-- Initial content update
	M.update_monitor()

	return win, buf
end

-- Show monitor window
function M.show_monitor()
	if M.monitor.is_visible then
		return
	end

	M.create_monitor_window()
	M.monitor.is_visible = true

	-- Start auto-refresh timer
	if M.monitor.timer then
		vim.fn.timer_stop(M.monitor.timer)
	end

	M.monitor.timer = vim.fn.timer_start(M.monitor.refresh_interval, function()
		if M.monitor.is_visible and M.monitor.buf and vim.api.nvim_buf_is_valid(M.monitor.buf) then
			M.update_monitor()
		else
			-- Stop timer if monitor is not visible
			if M.monitor.timer then
				vim.fn.timer_stop(M.monitor.timer)
				M.monitor.timer = nil
			end
		end
	end, { ["repeat"] = -1 })

	vim.notify("Claude Monitor started", vim.log.levels.INFO)
end

-- Hide monitor window
function M.hide_monitor()
	if not M.monitor.is_visible then
		return
	end

	-- Stop timer
	if M.monitor.timer then
		vim.fn.timer_stop(M.monitor.timer)
		M.monitor.timer = nil
	end

	-- Close window
	if M.monitor.win and vim.api.nvim_win_is_valid(M.monitor.win) then
		vim.api.nvim_win_close(M.monitor.win, true)
	end

	-- Delete buffer
	if M.monitor.buf and vim.api.nvim_buf_is_valid(M.monitor.buf) then
		vim.api.nvim_buf_delete(M.monitor.buf, { force = true })
	end

	M.monitor.win = nil
	M.monitor.buf = nil
	M.monitor.is_visible = false

	vim.notify("Claude Monitor stopped", vim.log.levels.INFO)
end

-- Toggle monitor window
function M.toggle_monitor()
	if M.monitor.is_visible then
		M.hide_monitor()
	else
		M.show_monitor()
	end
end

-- Setup function
function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	-- Create autocmd for cleanup on VimLeave
	vim.api.nvim_create_augroup("ClaudeTerminal", { clear = true })
	vim.api.nvim_create_autocmd("VimLeave", {
		group = "ClaudeTerminal",
		callback = function()
			M.cleanup()
		end,
	})

	-- Add command to show all sessions status
	vim.api.nvim_create_user_command("ClaudeSessions", function()
		M.show_sessions_status()
	end, { desc = "Show all Claude sessions status" })

	-- Add command to toggle Claude monitor
	vim.api.nvim_create_user_command("ClaudeMonitor", function()
		M.toggle_monitor()
	end, { desc = "Toggle Claude sessions monitor" })
end

return M
