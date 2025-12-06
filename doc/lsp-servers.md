# LSP Servers Feature

The **LSP Servers** feature allows you to enable or disable Language Server Protocol servers on a per-project basis. Disabled servers are persisted to `.neoconf.json` and will remain disabled across Neovim restarts.

## Enabling the Feature

```lua
require("nvim-control-center").setup({
  features = {
    lsp_servers = true,
  },
})
```

## How It Works

### Discovery

The feature automatically discovers LSP servers from multiple sources:

1. **Active LSP configs** - Servers registered via `vim.lsp.enable()` or nvim-lspconfig
2. **Running clients** - Currently active LSP clients
3. **Disabled servers** - Servers previously disabled in `.neoconf.json`

This ensures you always see all relevant LSP servers, including ones you've disabled.

### Toggling

When you toggle an LSP server:

- **Disabling**: 
  - Saves `lsp.<server_name>.disabled = true` to `.neoconf.json`
  - Calls `vim.lsp.enable(server_name, false)` to prevent future starts
  - Stops all active clients for that server with `vim.lsp.stop_client()`

- **Enabling**:
  - Removes the `disabled` entry from `.neoconf.json`
  - Calls `vim.lsp.enable(server_name, true)` 
  - Triggers a `FileType` autocommand to restart the server for the current buffer

### Persistence Format

Settings are stored in `.neoconf.json`:

```json
{
  "lsp": {
    "lua_ls": {
      "disabled": true
    },
    "pyright": {
      "disabled": true
    }
  }
}
```

## UI

The LSP Servers tab displays:

| Icon | Meaning |
|------|---------|
| ✓ (tick) | Server is enabled |
| ✗ (cross) | Server is disabled |

### Navigation

- Press `Enter` or click to toggle the server
- Use `j/k` to navigate between servers
- Use `h/l` to switch to other tabs

## Integration with Other Plugins

### nvim-lspconfig

If you use nvim-lspconfig, the feature works seamlessly - it detects servers configured via `lspconfig.server.setup()`.

### Reading Disabled State Programmatically

You can check if an LSP is disabled in your own code:

```lua
local neoconf = require("neoconf")
local path = "lsp.lua_ls.disabled"
local is_disabled = neoconf.get(path, nil, { ["local"] = true, global = true }) == true
```

Or use the feature's public API:

```lua
local lsp_servers = require("nvim-control-center.features.lsp_servers")
local is_disabled = lsp_servers.is_lsp_disabled("lua_ls")
```

## Use Cases

- **Disable slow LSPs** in large projects for faster editing
- **Disable conflicting LSPs** (e.g., tsserver vs denols)
- **Per-project LSP configuration** without modifying global config
- **Temporarily disable an LSP** for debugging

## Startup Behavior

On Neovim startup, disabled LSP servers are read from `.neoconf.json` and their `disabled` state is applied via `vim.lsp.enable(name, false)`. This prevents them from starting automatically.

The UI icon (tick/cross) reflects the true state by checking `.neoconf.json` directly, not just the in-memory state.
