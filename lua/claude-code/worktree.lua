local M = {}

-- Get git root directory
local function get_git_root()
	local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null")
	if vim.v.shell_error == 0 then
		return vim.fn.trim(git_root)
	end
	return nil
end

-- Get the main git repository root (not worktree)
local function get_main_git_root()
	-- Get the common directory which points to the main repo
	local common_dir = vim.fn.system("git rev-parse --git-common-dir 2>/dev/null")
	if vim.v.shell_error == 0 then
		common_dir = vim.fn.trim(common_dir)
		-- If it's absolute path, get its parent; if relative, resolve it
		if common_dir:sub(1, 1) == "/" then
			return vim.fn.fnamemodify(common_dir, ":h")
		else
			return vim.fn.fnamemodify(vim.fn.getcwd() .. "/" .. common_dir, ":p:h")
		end
	end
	return get_git_root() -- fallback
end

-- Get current worktree
local function get_current_worktree()
	local git_root = get_git_root()
	if not git_root then
		return nil
	end

	local current_dir = vim.fn.getcwd()
	local worktree_list = vim.fn.system("git worktree list --porcelain")

	for line in worktree_list:gmatch("[^\n]+") do
		if line:match("^worktree ") then
			local path = line:match("^worktree (.+)")
			if current_dir:find(path, 1, true) == 1 then
				return path
			end
		end
	end

	return git_root
end

-- List all worktrees
function M.list_worktrees()
	local git_root = get_git_root()
	if not git_root then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return {}
	end

	local worktree_list = vim.fn.system("git worktree list --porcelain")
	local worktrees = {}
	local current_worktree = {}

	for line in worktree_list:gmatch("[^\n]+") do
		if line:match("^worktree ") then
			if next(current_worktree) then
				table.insert(worktrees, current_worktree)
			end
			current_worktree = {
				path = line:match("^worktree (.+)"),
				branch = nil,
				bare = false,
				detached = false,
				locked = false,
			}
		elseif line:match("^HEAD ") then
			current_worktree.head = line:match("^HEAD (.+)")
		elseif line:match("^branch ") then
			current_worktree.branch = line:match("^branch refs/heads/(.+)")
		elseif line:match("^detached") then
			current_worktree.detached = true
		elseif line:match("^bare") then
			current_worktree.bare = true
		elseif line:match("^locked") then
			current_worktree.locked = true
			current_worktree.lock_reason = line:match("^locked (.*)") or ""
		end
	end

	if next(current_worktree) then
		table.insert(worktrees, current_worktree)
	end

	return worktrees
end

-- Create new worktree
function M.create_worktree(branch_name, path)
	local git_root = get_git_root()
	if not git_root then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return false
	end

	if not branch_name or branch_name == "" then
		vim.notify("Branch name is required", vim.log.levels.ERROR)
		return false
	end

	-- Check if branch already exists
	local branch_check = vim.fn.system(
		string.format("git show-ref --verify --quiet refs/heads/%s", vim.fn.shellescape(branch_name))
	)
	if vim.v.shell_error == 0 then
		vim.notify(string.format("Branch '%s' already exists", branch_name), vim.log.levels.ERROR)
		return false, nil
	end

	-- Check if worktree with this branch already exists
	local existing_worktrees = M.list_worktrees()
	for _, wt in ipairs(existing_worktrees) do
		if wt.branch == branch_name then
			vim.notify(
				string.format("Worktree for branch '%s' already exists at: %s", branch_name, wt.path),
				vim.log.levels.ERROR
			)
			return false, nil
		end
	end

	-- Default path: create under main git repository's .git/worktrees
	if not path or path == "" then
		local main_repo_root = get_main_git_root()
		path = main_repo_root .. "/.git/worktrees/" .. branch_name
	end

	-- Check if target path already exists (file or directory)
	if vim.fn.filereadable(path) == 1 or vim.fn.isdirectory(path) == 1 then
		vim.notify(string.format("Path already exists: %s", path), vim.log.levels.ERROR)
		return false, nil
	end

	-- Change to main git repository root before executing git worktree command
	local old_cwd = vim.fn.getcwd()
	local main_repo_root = get_main_git_root()
	vim.cmd("cd " .. vim.fn.fnameescape(main_repo_root))

	local cmd = string.format(
		"git worktree add -b %s %s",
		vim.fn.shellescape(branch_name),
		vim.fn.shellescape(path)
	)
	local result = vim.fn.system(cmd)

	-- Restore directory
	vim.cmd("cd " .. vim.fn.fnameescape(old_cwd))

	if vim.v.shell_error == 0 then
		vim.notify(string.format("Created worktree: %s -> %s", branch_name, path), vim.log.levels.INFO)

		-- Refresh nvim-tree if available
		vim.schedule(function()
			local ok, nvim_tree_api = pcall(require, "nvim-tree.api")
			if ok then
				nvim_tree_api.tree.reload()
			end
		end)

		return true, path
	else
		vim.notify(string.format("Failed to create worktree: %s", result), vim.log.levels.ERROR)
		return false, nil
	end
end

-- Switch to existing worktree
function M.switch_to_worktree(path)
	if not path then
		vim.notify("Worktree path is required", vim.log.levels.ERROR)
		return false
	end

	-- Check if path exists
	if vim.fn.isdirectory(path) == 0 then
		vim.notify(string.format("Worktree path does not exist: %s", path), vim.log.levels.ERROR)
		return false
	end

	-- Change directory
	vim.cmd("cd " .. vim.fn.fnameescape(path))

	-- Update Claude terminal context if available
	local ok, terminal = pcall(require, "claude-code.terminal")
	if ok then
		local session_name = vim.fn.fnamemodify(path, ":t")
		terminal.switch_context(session_name, path)
	end

	-- Refresh nvim-tree if available
	local ok, nvim_tree_api = pcall(require, "nvim-tree.api")
	if ok then
		-- Make sure nvim-tree is open and change root
		if not nvim_tree_api.tree.is_visible() then
			nvim_tree_api.tree.open()
		end
		nvim_tree_api.tree.change_root(path)
		nvim_tree_api.tree.reload()
	end

	vim.notify(string.format("Switched to worktree: %s", path), vim.log.levels.INFO)
	return true
end

-- Remove worktree
function M.remove_worktree(path, force)
	local git_root = get_git_root()
	if not git_root then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return false
	end

	if not path or path == "" then
		vim.notify("Worktree path is required", vim.log.levels.ERROR)
		return false
	end

	local cmd = string.format("git worktree remove %s %s", force and "--force" or "", path)
	local result = vim.fn.system(cmd)

	if vim.v.shell_error == 0 then
		vim.notify(string.format("Removed worktree: %s", path), vim.log.levels.INFO)
		return true
	else
		vim.notify(string.format("Failed to remove worktree: %s", result), vim.log.levels.ERROR)
		return false
	end
end

-- Get worktree display name
function M.get_worktree_display_name(worktree)
	local name = vim.fn.fnamemodify(worktree.path, ":t")
	if worktree.branch then
		name = name .. " (" .. worktree.branch .. ")"
	elseif worktree.detached then
		name = name .. " (detached)"
	end

	return name
end

-- Interactive worktree picker
function M.pick_worktree(callback)
	local worktrees = M.list_worktrees()
	if #worktrees == 0 then
		vim.notify("No worktrees found", vim.log.levels.INFO)
		return
	end

	local items = {}
	for i, wt in ipairs(worktrees) do
		table.insert(items, {
			text = M.get_worktree_display_name(wt),
			path = wt.path,
			worktree = wt,
			index = i,
		})
	end

	-- Try telescope first
	local ok, telescope = pcall(require, "telescope")
	if ok then
		local pickers = require("telescope.pickers")
		local finders = require("telescope.finders")
		local conf = require("telescope.config").values
		local actions = require("telescope.actions")
		local action_state = require("telescope.actions.state")

		pickers
			.new({}, {
				prompt_title = "Git Worktrees",
				finder = finders.new_table({
					results = items,
					entry_maker = function(entry)
						return {
							value = entry,
							display = entry.text,
							ordinal = entry.text,
						}
					end,
				}),
				sorter = conf.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, map)
					actions.select_default:replace(function()
						actions.close(prompt_bufnr)
						local selection = action_state.get_selected_entry()
						if selection and callback then
							callback(selection.value.worktree, selection.value.path)
						end
					end)
					return true
				end,
			})
			:find()
	else
		-- Fallback to vim.ui.select
		vim.ui.select(items, {
			prompt = "Select worktree:",
			format_item = function(item)
				return item.text
			end,
		}, function(choice)
			if choice and callback then
				callback(choice.worktree, choice.path)
			end
		end)
	end
end

-- Public functions
M.get_git_root = get_git_root
M.get_main_git_root = get_main_git_root
M.get_current_worktree = get_current_worktree

return M
