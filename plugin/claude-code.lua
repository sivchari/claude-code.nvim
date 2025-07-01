-- Check if already loaded
if vim.g.loaded_claude_code then
	return
end
vim.g.loaded_claude_code = true

-- Load the plugin
require("claude-code").setup()
