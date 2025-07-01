-- Example configuration for testing claude-code locally

-- For lazy.nvim users:
return {
	dir = vim.fn.expand("~/workspace/sivchari/claude-code"), -- Adjust path as needed
	name = "claude-code",
	config = function()
		require("claude-code").setup({
			width = 0.5,
			height = 1,
			position = "right",
			cmd = "claude",
			mappings = {
				toggle = "<leader>cc",
				focus = "<leader>cf",
				close = "<leader>cq",
			},
			auto_scroll = true,
			start_in_insert = true,
		})

		-- Optional: Add which-key descriptions if you use which-key
		local ok, which_key = pcall(require, "which-key")
		if ok then
			which_key.register({
				["<leader>c"] = {
					name = "Claude",
					c = { "<cmd>Claude<cr>", "Toggle Claude" },
					f = { "<cmd>ClaudeFocus<cr>", "Focus Claude" },
					q = { "<cmd>ClaudeClose<cr>", "Close Claude" },
					s = { "<cmd>ClaudeSendFile<cr>", "Send File" },
					p = { "<cmd>ClaudePrompt<cr>", "Prompt Claude" },
					d = { "<cmd>ClaudeSendDiagnostics<cr>", "Send Diagnostics" },
					h = { "<cmd>ClaudeHistory<cr>", "Show History" },
					r = { "<cmd>ClaudeRestart<cr>", "Restart Claude" },
				},
			})
		end
	end,
	keys = {
		{ "<leader>cc", "<cmd>Claude<cr>", desc = "Toggle Claude" },
		{ "<leader>cf", "<cmd>ClaudeFocus<cr>", desc = "Focus Claude" },
		{ "<leader>cq", "<cmd>ClaudeClose<cr>", desc = "Close Claude" },
		{ "<leader>cs", "<cmd>ClaudeSendFile<cr>", desc = "Send File", mode = "n" },
		{ "<leader>cs", "<cmd>ClaudeSendSelection<cr>", desc = "Send Selection", mode = "v" },
		{ "<leader>cp", "<cmd>ClaudePrompt<cr>", desc = "Prompt Claude" },
		{ "<leader>cd", "<cmd>ClaudeSendDiagnostics<cr>", desc = "Send Diagnostics" },
	},
}
