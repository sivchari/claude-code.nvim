local M = {}
local worktree = require("claude-code.worktree")

-- Add custom nvim-tree actions for worktree management
function M.setup()
	local ok, nvim_tree = pcall(require, "nvim-tree")
	if not ok then
		return
	end

	local api = require("nvim-tree.api")

	-- Custom action to create worktree
	local create_worktree_action = function()
		vim.ui.input({ prompt = "Branch name: " }, function(branch_name)
			if branch_name and branch_name ~= "" then
				vim.ui.input({
					prompt = "Path (optional): ",
					default = vim.fn.fnamemodify(vim.fn.getcwd(), ":h") .. "/" .. branch_name,
				}, function(path)
					if worktree.create_worktree(branch_name, path) then
						api.tree.reload()
					end
				end)
			end
		end)
	end

	-- Custom action to switch worktree
	local switch_worktree_action = function()
		worktree.pick_worktree(function(wt, path)
			if worktree.switch_to_worktree(path) then
				api.tree.reload()

				-- Update Claude terminal context if it's open
				local terminal = require("claude-code.terminal")
				local info = terminal.get_current_session()
				if info.is_visible or info.terminal_valid then
					local session_id = vim.fn.fnamemodify(path, ":t")
					-- Add delay to ensure directory change is complete
					vim.defer_fn(function()
						terminal.switch_context(session_id, path)
					end, 500)
				end
			end
		end)
	end

	-- Custom action to remove worktree
	local remove_worktree_action = function()
		worktree.pick_worktree(function(wt, path)
			local current_path = vim.fn.getcwd()
			if path == current_path then
				vim.notify("Cannot remove current worktree", vim.log.levels.WARN)
				return
			end

			vim.ui.select({ "No", "Yes", "Force" }, {
				prompt = string.format("Remove worktree %s?", path),
			}, function(choice)
				if choice == "Yes" then
					if worktree.remove_worktree(path, false) then
						api.tree.reload()
					end
				elseif choice == "Force" then
					if worktree.remove_worktree(path, true) then
						api.tree.reload()
					end
				end
			end)
		end)
	end

	-- Function to add Claude keymaps to nvim-tree
	local function add_claude_keymaps(bufnr)
		-- Worktree management
		vim.keymap.set("n", "gwa", create_worktree_action, {
			buffer = bufnr,
			desc = "Create worktree",
		})

		vim.keymap.set("n", "gws", switch_worktree_action, {
			buffer = bufnr,
			desc = "Switch worktree",
		})

		vim.keymap.set("n", "gwr", remove_worktree_action, {
			buffer = bufnr,
			desc = "Remove worktree",
		})

		-- Quick worktree creation
		vim.keymap.set("n", "gwn", function()
			vim.ui.input({ prompt = "New branch name: " }, function(branch_name)
				if branch_name and branch_name ~= "" then
					local success, path = worktree.create_worktree(branch_name)
					if success then
						worktree.switch_to_worktree(path)
						vim.notify(string.format("Switched to worktree: %s", branch_name), vim.log.levels.INFO)
					end
				end
			end)
		end, {
			buffer = bufnr,
			desc = "Create and switch to new worktree",
		})
	end

	-- Helper function to integrate with nvim-tree
	M.on_attach = function(bufnr)
		-- Disable treesitter for nvim-tree buffer to prevent errors
		local treesitter_fix = require("claude-code.treesitter_fix")
		treesitter_fix.disable_for_buffer(bufnr)

		-- Add Claude keymaps
		add_claude_keymaps(bufnr)

		-- Refresh tree when session states change
		vim.api.nvim_create_autocmd("User", {
			pattern = "ClaudeSessionUpdate",
			callback = function()
				api.tree.reload()
			end,
		})
	end
end

return M
