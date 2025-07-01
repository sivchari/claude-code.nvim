# 🤖 claude-code.nvim

A streamlined Neovim plugin for seamlessly using Claude Code with git worktree support.

![Claude Code Demo](https://via.placeholder.com/800x400/1e1e2e/cdd6f4?text=Claude+Code+Demo)

## ✨ Features

### 🎯 Core Features
- **One-key Claude toggle** with `<leader>cc` - instant access to Claude CLI
- **Per-worktree Claude sessions** - each git worktree gets its own independent Claude instance
- **Real-time session monitoring** - see all Claude sessions at a glance
- **Seamless worktree management** - create, switch, and manage worktrees from Neovim
- **nvim-tree integration** - worktree operations directly from the file explorer

### 🚀 Advanced Features
- **Live session monitor** - dedicated window showing all Claude sessions in real-time
- **Independent terminal sessions** - each worktree maintains its own Claude CLI state
- **Automatic context switching** - Claude sessions automatically update when switching worktrees
- **Clean interface** - minimal, distraction-free design

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "sivchari/claude-code.nvim",
  config = function()
    require("claude-code").setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "sivchari/claude-code.nvim",
  config = function()
    require("claude-code").setup()
  end
}
```

## 🎮 Usage

### Basic Operations

| Keymap | Command | Description |
|--------|---------|-------------|
| `<leader>cc` | `:Claude` | Toggle Claude CLI (main function) |
| `<leader>cl` | `:ClaudeSessions` | Show all Claude sessions status |
| `<leader>cm` | `:ClaudeMonitor` | Toggle real-time sessions monitor |
| `<leader>cw` | - | Switch between worktrees |

### Git Worktree Management

| Command | Description |
|---------|-------------|
| `:ClaudeWorktreeCreate [branch]` | Create new worktree |
| `:ClaudeWorktreeSwitch` | Switch to different worktree |
| `:ClaudeWorktreeRemove` | Remove worktree with confirmation |

### nvim-tree Integration

When in nvim-tree buffer:

| Keymap | Description |
|--------|-------------|
| `gwa` | Create new worktree |
| `gws` | Switch to different worktree |
| `gwr` | Remove worktree |
| `gwn` | Quick: create new worktree and switch |

## 📊 Real-time Session Monitor

Press `<leader>cm` to toggle the Claude sessions monitor:

```
┌─ Claude Sessions ─┐
│ ● feature-1      │  ← Claude running
│ ◑ feature-2      │  ← Waiting for input
│ ◐ main           │  ← Terminal ready
│ ○ hotfix         │  ← No session
│ ●* dev           │  ← Running & visible
├─────────────────┤
│ ● Running       │  ← Legend
│ ◑ Waiting       │
│ ◐ Ready         │
│ ○ None          │
│ * Visible       │
└─────────────────┘
```

- **●** = Claude CLI running
- **◑** = Claude waiting for user input
- **◐** = Terminal ready (Claude not active)
- **○** = No session
- **\*** = Currently visible session
- **Auto-refresh every 2 seconds**

## 🔄 Workflow Examples

### Creating a new feature branch

1. **Create worktree**: `<leader>cw` → select "Create new worktree"
2. **Open Claude**: `<leader>cc` (automatically creates session for this worktree)
3. **Monitor sessions**: `<leader>cm` to see all active Claude sessions
4. **Switch between features**: `<leader>cw` to change worktrees, Claude sessions switch automatically

### Working with multiple features

1. **Start monitor**: `<leader>cm` to see all sessions
2. **Switch worktrees**: `<leader>cw` - Claude context switches automatically
3. **Independent work**: Each worktree maintains its own Claude conversation history
4. **Parallel development**: Work on multiple features simultaneously with separate Claude instances

## ⚙️ Configuration

### Default Configuration

```lua
require("claude-code").setup({
  width = 0.5,          -- Claude terminal width (50% of screen)
  height = 1,           -- Claude terminal height (full height)
  position = "right",   -- Terminal position
  cmd = "claude",       -- Claude CLI command
  mappings = {
    toggle = "<leader>cc", -- Main toggle keymap
  },
  auto_scroll = true,
  start_in_insert = true,
})
```

### Custom Configuration Example

```lua
require("claude-code").setup({
  width = 0.6,          -- Wider Claude terminal
  mappings = {
    toggle = "<leader>ai", -- Custom keymap
  },
})
```

## 🏗️ Architecture

```
┌─────────────────┬─────────────────┬─────────────────┐
│   Worktree 1    │   Worktree 2    │   Worktree 3    │
│   (feature-1)   │   (feature-2)   │   (main)        │
├─────────────────┼─────────────────┼─────────────────┤
│ Claude Session A│ Claude Session B│ Claude Session C│
│ ● Running       │ ◐ Ready         │ ○ None          │
└─────────────────┴─────────────────┴─────────────────┘
```

Each worktree maintains:
- **Independent Claude CLI session**
- **Separate conversation history**
- **Isolated terminal state**
- **Automatic context switching**

## 🔧 Requirements

- **Neovim >= 0.8.0**
- **Claude CLI** installed and available in PATH
- **Git** for worktree functionality
- **nvim-tree** (optional, for file explorer integration)

## 🐛 Troubleshooting

### Claude CLI not found
```bash
# Install Claude CLI
# Visit https://claude.ai/download to get the latest installer
# or install via your package manager if available
```

### Sessions not switching properly
- Use `<leader>cl` to verify session status
- Check the monitor with `<leader>cm` to see all sessions
- Restart with `<leader>cc` to toggle Claude off/on

### Monitor not updating
- Check if monitor is visible with `<leader>cm`
- Sessions update every 2 seconds automatically
- Use `<leader>cl` to manually check session status

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch: `git checkout -b feature/amazing-feature`
3. Commit your changes: `git commit -m 'Add amazing feature'`
4. Push to the branch: `git push origin feature/amazing-feature`
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

**Happy coding with Claude! 🚀**
