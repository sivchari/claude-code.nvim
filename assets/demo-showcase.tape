# Claude Code Neovim Plugin Showcase
# Optimized for social media and quick demos

Output demo-showcase.gif

# Settings for high-quality, compact demo
Set FontSize 16
Set Width 1200
Set Height 800
Set TypingSpeed 60ms
Set Theme "OneDark"
Set Padding 10

# Title card
Type "# 🤖 claude-code.nvim Demo"
Sleep 2s
Enter
Type "# Seamless Claude AI integration for Neovim"
Sleep 2s
Enter
Enter
Sleep 1s

# Demo: Complete Workflow with claude-code.nvim
Type "# === claude-code.nvim Workflow Demo ==="
Sleep 2s
Enter

# Step 1: Open nvim-tree and create new worktree
Type "nvim"
Enter
Sleep 3s

# Open nvim-tree
Ctrl+Q
Sleep 2s

# Create new worktree using gwa in nvim-tree
Type "gwa"
Sleep 2s

# Enter branch name when prompted
Type "feature/documentation"
Enter
Enter
Sleep 3s

# Step 2: Show session monitor
Type " cm"
Sleep 4s

# Step 3: Open nvim-tree again and switch to the new worktree
Ctrl+Q
Sleep 2s
Type "gws"
Sleep 2s
Up
Enter
Sleep 2s

# Step 4: Create DEMO.md file using nvim-tree
Type "a"
Sleep 1s
Type "DEMO.md"
Enter
Sleep 2s

# Search and open the created file
Type "/DEMO.md"
Enter
Sleep 1s
Enter
Sleep 2s

# Make sure we're in normal mode
Escape
Escape
Sleep 1s

# Step 5: Show session monitor again
Type ",cm"
Sleep 3s

# Ensure normal mode before opening Claude
Escape
Sleep 1s

# Step 6: Open Claude and ask a question
Type ",cc"
Enter
Sleep 4s

# Ask Claude about the project
Type "What do you think about this project? Is the combination of Neovim + Claude + git worktree useful?"
Enter
Sleep 5s

# Step 7: Hide Claude with Ctrl+Q
Ctrl+Q
Sleep 2s

# Write plugin features
Type "i"
Type "# claude-code.nvim Features"
Enter
Enter
Type "## Core Features"
Enter
Type "- **<leader>cc**: Toggle Claude terminal"
Enter
Type "- **<leader>cl**: Show session status"
Enter
Type "- **<leader>cm**: Session monitor"
Enter
Type "- **Per-worktree sessions**: Each git worktree gets independent Claude"
Enter
Enter
Type "## Worktree Management"
Enter
Type "- **gwa**: Create new worktree (from nvim-tree)"
Enter
Type "- **gws**: Switch between worktrees (from nvim-tree)"
Enter

# Step 6: Save file
Escape
Type ":w"
Enter
Sleep 2s

# Step 9: Open Claude again to show it's still running in background
Type ",cc"
Sleep 4s

# Show Claude is still available and working in background
Type "Claude is still running in the background! Amazing per-worktree sessions."
Sleep 3s

# Hide Claude again
Ctrl+Q
Sleep 2s

# Continue writing in DEMO.md - enter insert mode
Type "i"
Sleep 1s
Enter
Type "## Summary"
Enter
Type "🚀 claude-code.nvim is amazing!"
Enter
Type "- Seamless Claude integration with Neovim"
Enter
Type "- Per-worktree independent sessions"
Enter
Type "- Real-time session monitoring"
Enter
Enter
Type "Install: https://github.com/sivchari/claude-code.nvim"
Sleep 3s

# Save and exit
Escape
Type ":wq"
Enter
Sleep 2s
