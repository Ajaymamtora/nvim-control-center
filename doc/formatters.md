# Formatters Feature

The **Formatters** feature allows you to enable or disable formatters on a per-project basis. This integrates with [conform.nvim](https://github.com/stevearc/conform.nvim) to provide project-specific formatter control.

## Enabling the Feature

```lua
require("nvim-control-center").setup({
  features = {
    formatters = true,
  },
})
```

## How It Works

### Discovery

The feature discovers formatters by calling `conform.list_all_formatters()`, which returns all formatters that conform.nvim knows about for the current filetype and globally.

Additionally, it reads `.neoconf.json` to include formatters that were previously disabled (so you can re-enable them).

### Toggling

When you toggle a formatter:

- **Disabling**: Saves `formatter.<formatter_name>.disabled = true` to `.neoconf.json`
- **Enabling**: Removes the `disabled` entry from `.neoconf.json`

Unlike LSP servers, formatters don't have a built-in enable/disable mechanism. Instead, conform.nvim must be configured to check the disabled state.

### Persistence Format

Settings are stored in `.neoconf.json`:

```json
{
  "formatter": {
    "prettier": {
      "disabled": true
    },
    "black": {
      "disabled": true
    }
  }
}
```

## Integrating with conform.nvim

For the disable state to take effect, you need to configure conform.nvim to check neoconf:

### Option 1: Using `condition` per formatter

```lua
local function with_disable_check(formatter_name, original_condition)
  return function(self, ctx)
    local neoconf = require("neoconf")
    local path = "formatter." .. formatter_name .. ".disabled"
    if neoconf.get(path, nil, { ["local"] = true, global = true }) == true then
      return false
    end
    if original_condition then
      return original_condition(self, ctx)
    end
    return true
  end
end

require("conform").setup({
  formatters_by_ft = {
    javascript = { "prettier" },
    python = { "black" },
  },
  formatters = {
    prettier = {
      condition = with_disable_check("prettier"),
    },
    black = {
      condition = with_disable_check("black"),
    },
  },
})
```

### Option 2: Global format check

```lua
require("conform").setup({
  format_on_save = function(bufnr)
    -- Check if any formatter for this buffer is disabled
    local formatters = require("conform").list_formatters(bufnr)
    local neoconf = require("neoconf")
    
    for _, formatter in ipairs(formatters) do
      local path = "formatter." .. formatter.name .. ".disabled"
      if neoconf.get(path, nil, { ["local"] = true, global = true }) == true then
        -- Skip this formatter
      else
        -- Use this formatter
      end
    end
  end,
})
```

## UI

The Formatters tab displays:

| Icon | Meaning |
|------|---------|
| ✓ (tick) | Formatter is enabled |
| ✗ (cross) | Formatter is disabled |

### Navigation

- Press `Enter` or click to toggle the formatter
- Use `j/k` to navigate between formatters
- Use `h/l` to switch to other tabs

## Checking Formatter State Programmatically

```lua
local formatters = require("nvim-control-center.features.formatters")
local is_disabled = formatters.is_formatter_disabled("prettier")
```

Or directly via neoconf:

```lua
local neoconf = require("neoconf")
local path = "formatter.prettier.disabled"
local is_disabled = neoconf.get(path, nil, { ["local"] = true, global = true }) == true
```

## Use Cases

- **Disable prettier** in projects using a different formatter
- **Disable slow formatters** for large files
- **Project-specific formatting rules** without global config changes
- **Temporarily disable formatting** for debugging

## Notes

- Formatters must be known to conform.nvim to appear in the list
- The disabled state only affects formatters that check neoconf (see integration above)
- Changes take effect immediately - the next format operation will respect the new state
