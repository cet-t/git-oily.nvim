# git-oily.nvim

A lightweight Git TUI plugin for Neovim. Buffer-based, fugitive-inspired.
Toggle on/off when needed — slippery git operations.

## Features

- **Oil Mode** — Toggleable overlay. Enable only when you need git keys.
- **Status buffer** — Stage/unstage/diff/commit from one view.
- **Diff viewer** — Floating window with syntax highlighting.
- **Commit buffer** — Write messages with `gitcommit` filetype.
- **Log viewer** — Browse commit history, expand any commit.
- **Stash manager** — List, apply, pop, drop, and view stashes.
- **nvim-tree integration** — Git operations from the file tree.

## Requirements

- Neovim >= 0.10 (for `vim.system`)
- Git

## Installation

```lua
-- lazy.nvim
{
  "cet-t/git-oily.nvim",
  cmd = { "Oily", "OilyToggle" },
  opts = {},
}
```

## Usage

### Commands

| Command | Action |
|---------|--------|
| `:Oily` | Open status buffer |
| `:Oily toggle` | Enable/disable Oil Mode |
| `:Oily log` | Open commit log |
| `:Oily stash` | Open stash list |

### Oil Mode

Oil Mode overlays git keymaps onto normal buffers. Toggle it on, use git
keys, toggle it off when done. No interference when disabled.

```
:Oily toggle    " enable
gs gd gc ...    " git operations
g.              " disable
```

**Buffer keymaps (Oil Mode)**:

| Key | Action |
|-----|--------|
| `gs` | Stage/unstage current file |
| `gd` | Show diff (unstaged) |
| `gD` | Show diff (staged) |
| `gc` | Open commit buffer |
| `gS` | Stage all |
| `gu` | Unstage all |
| `g.` | Disable Oil Mode |

### Status Buffer

```
:Oily
```

**Keymaps**:

| Key | Action |
|-----|--------|
| `-` | Toggle stage/unstage |
| `dd` / `=` | Show diff |
| `S` | Stage all |
| `u` | Unstage all |
| `cc` | Commit |
| `ca` | Amend |
| `r` | Refresh |
| `q` | Close |

### Commit Buffer

Write your commit message and save (`:wq`) to commit. Cancel with `:cq`.

### Log Viewer

```
:Oily log
```

| Key | Action |
|-----|--------|
| `dd` / `=` | Show selected commit diff |
| `r` | Refresh |
| `q` | Close |

### Stash Viewer

```
:Oily stash
```

| Key | Action |
|-----|--------|
| `dd` / `=` | Show stash diff |
| `a` | Apply stash |
| `p` | Pop stash |
| `d` | Drop stash |
| `r` | Refresh |
| `q` | Close |

### nvim-tree Integration

Add git operations to your nvim-tree:

```lua
require("nvim-tree").setup({
  on_attach = function(bufnr)
    -- ... your default keymaps ...
    require("git-oily.integration.nvim_tree").on_attach(bufnr)
  end,
})
```

| Key | Action |
|-----|--------|
| `gh` | Diff file (horizontal) |
| `gv` | Diff file (vertical) |
| `gs` | Stage/unstage file |
| `gS` | Stage all |
| `gu` | Unstage all |
| `gc` | Commit |

## Configuration

```lua
require("git-oily").setup({
  keymaps = {
    status = {
      toggle = "-",
      diff = "dd",
      diff_split = "=",
      stage_all = "S",
      unstage_all = "u",
      commit = "cc",
      amend = "ca",
      refresh = "r",
      quit = "q",
    },
    log = {
      diff = "dd",
      refresh = "r",
      quit = "q",
    },
    stash = {
      diff = "dd",
      apply = "a",
      pop = "p",
      drop = "d",
      refresh = "r",
      quit = "q",
    },
  },
  signs = {
    staged = "+",
    unstaged = "-",
    untracked = "?",
  },
})
```

## License

MIT
