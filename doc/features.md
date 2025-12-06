# nvim-control-center Features

This documentation covers the built-in feature modules that extend nvim-control-center with automatic plugin integration.

## Overview

nvim-control-center includes optional **feature modules** that automatically integrate with popular Neovim plugins:

| Feature | Description | Plugin Integration |
|---------|-------------|-------------------|
| [LSP Servers](lsp-servers.md) | Toggle LSP servers on/off per project | `vim.lsp` / nvim-lspconfig |
| [Formatters](formatters.md) | Toggle formatters on/off per project | conform.nvim |
| [Tasks](tasks.md) | Manage and run overseer.nvim tasks | overseer.nvim |

## Enabling Features

Features are disabled by default. Enable them in your setup:

### Simple Enable (Boolean)

```lua
require("nvim-control-center").setup({
  features = {
    lsp_servers = true,  -- LSP server toggle tab
    formatters = true,   -- Formatter toggle tab
    tasks = true,        -- Overseer tasks tab
  },
})
```

### With Customization (Table)

You can customize the tab label and icon for any feature:

```lua
require("nvim-control-center").setup({
  features = {
    lsp_servers = {
      enabled = true,
      label = "Language Servers",  -- Custom tab name
      icon = "󰒋",                   -- Custom icon
    },
    formatters = {
      enabled = true,
      label = "Code Formatters",
      icon = "󰉢",
    },
    tasks = {
      enabled = true,
      label = "Project Tasks",
      icon = "",
    },
  },
})
```

Each enabled feature adds a new **tab** to your control center UI.

## Feature Configuration Options

When using the table format, these options are available:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `true` | Whether the feature is enabled |
| `label` | string | (Feature default) | Tab label displayed in UI |
| `icon` | string | (Feature default) | Icon displayed before tab label |

**Note**: If you provide a table without `enabled`, it defaults to `true`.

## How Features Work

### Persistence with neoconf.nvim

All feature settings are persisted to `.neoconf.json` in your project root:

```json
{
  "lsp": {
    "lua_ls": { "disabled": true },
    "pyright": { "disabled": true }
  },
  "formatter": {
    "prettier": { "disabled": true }
  },
  "tasks": [
    { "name": "npm start", "start": "auto" }
  ]
}
```

This means:
- Settings are **project-specific** by default
- Settings persist across Neovim restarts
- You can commit `.neoconf.json` to share settings with your team

### Dynamic Settings

Feature tabs use **dynamic settings** that regenerate on each render. This allows:
- Real-time updates when you toggle items
- Expandable/collapsible UI sections
- Fresh data from neoconf on each view

## Feature Documentation

- **[LSP Servers](lsp-servers.md)** - Enable/disable LSP servers per project
- **[Formatters](formatters.md)** - Enable/disable formatters per project
- **[Tasks](tasks.md)** - Manage overseer.nvim tasks with auto-run support

## Default Icons and Labels

| Feature | Default Label | Default Icon |
|---------|---------------|--------------|
| lsp_servers | "LSP Servers" | "" |
| formatters | "Formatters" | "󰉢" |
| tasks | "Tasks" | "" |

## Creating Custom Features

You can create your own feature modules. See the [Custom Features Guide](custom-features.md) for details.
