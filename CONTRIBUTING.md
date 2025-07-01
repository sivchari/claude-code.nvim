# Contributing to claude-code.nvim

Thank you for your interest in contributing to claude-code.nvim! 🎉

## Development Setup

### Prerequisites

- Neovim >= 0.8.0
- Git
- Lua
- StyLua (for code formatting)
- Busted (for testing)

### Local Development

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/claude-code.git
   cd claude-code
   ```

2. **Install development dependencies**
   ```bash
   luarocks install busted
   luarocks install luacov
   npm install -g @johnnymorganz/stylua-cli
   ```

3. **Test your changes**
   ```bash
   # Run tests
   busted test/
   
   # Check code formatting
   stylua --check .
   
   # Format code
   stylua .
   ```

## Code Style

- Use tabs for indentation
- Follow existing patterns in the codebase
- Use descriptive variable names
- Add comments for complex logic
- Keep functions focused and small

## Testing

- Write tests for new features
- Ensure all existing tests pass
- Add integration tests for UI components when possible
- Use descriptive test names

Example test structure:
```lua
describe("feature name", function()
  it("should do something specific", function()
    -- Test implementation
    assert.equals(expected, actual)
  end)
end)
```

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```

2. **Make your changes**
   - Follow the code style guidelines
   - Add tests for new functionality
   - Update documentation if needed

3. **Test your changes**
   ```bash
   # Run all tests
   busted test/
   
   # Format code
   stylua .
   
   # Test plugin loads correctly
   nvim --headless --noplugin -u test/minimal_init.lua -c "lua require('claude-code').setup()" -c "q"
   ```

4. **Commit with conventional commits**
   ```bash
   git commit -m "feat: add amazing new feature"
   git commit -m "fix: resolve terminal session issue"
   git commit -m "docs: update README with new examples"
   ```

5. **Push and create pull request**
   ```bash
   git push origin feature/amazing-feature
   ```

## Commit Message Guidelines

Use [Conventional Commits](https://www.conventionalcommits.org/) format:

- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation changes
- `style:` formatting changes
- `refactor:` code refactoring
- `test:` adding tests
- `chore:` maintenance tasks

## Architecture Overview

```
claude-code.nvim/
├── lua/claude-code/
│   ├── init.lua              # Main plugin entry point
│   ├── terminal.lua          # Terminal management with sessions
│   ├── worktree.lua          # Git worktree operations
│   ├── commands.lua          # Plugin commands
│   ├── treesitter_fix.lua    # Treesitter compatibility
│   └── nvim_tree_extension.lua # nvim-tree integration
├── test/                     # Test files
└── .github/workflows/        # CI/CD configuration
```

### Key Components

- **Terminal Module**: Manages Claude CLI sessions per worktree
- **Worktree Module**: Handles git worktree operations
- **Session Management**: Each worktree gets independent Claude session
- **Real-time Monitor**: Shows status of all Claude sessions

## Reporting Issues

When reporting issues, please include:

1. Neovim version (`nvim --version`)
2. Plugin version or commit hash
3. Minimal reproduction case
4. Error messages or logs
5. Expected vs actual behavior

## Feature Requests

Before proposing new features:

1. Check existing issues and PRs
2. Consider if it fits the plugin's scope
3. Provide clear use cases and benefits
4. Be open to alternative solutions

## Questions?

- Check the [README](README.md) for usage instructions
- Browse [existing issues](https://github.com/sivchari/claude-code/issues)
- Start a [discussion](https://github.com/sivchari/claude-code/discussions)

Thank you for contributing! 🚀