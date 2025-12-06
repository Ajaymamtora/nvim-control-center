# nvim-control-center

A customizable control center for Neovim to manage settings and options with an enhanced UI powered by [nvzone/volt](https://github.com/nvzone/volt).

## ✨ Features

- **Modern Volt-based UI**: Beautiful, interactive interface with hover effects and smooth interactions
- **Modular Architecture**: Clean separation of state, layout, and components
- **Mouse Support**: Click tabs and settings, hover for visual feedback
- **Keyboard Navigation**: Vim-style hjkl navigation plus arrow keys
- **Customizable**: Full control over icons, colors, and behavior
- **Persistent Settings**: Backed by [folke/neoconf.nvim](https://github.com/folke/neoconf.nvim)
- **Type-Safe Configuration**: Support for booleans, strings, numbers, selects, and actions

### Built-in Feature Modules

| Feature | Description | Documentation |
|---------|-------------|---------------|
| **LSP Servers** | Toggle LSP servers on/off per project | [doc/lsp-servers.md](doc/lsp-servers.md) |
| **Formatters** | Toggle formatters on/off per project | [doc/formatters.md](doc/formatters.md) |
| **Tasks** | Manage overseer.nvim tasks with auto-run | [doc/tasks.md](doc/tasks.md) |

## 📦 Installation

### Requirements

- Neovim >= 0.10.0
- [folke/neoconf.nvim](https://github.com/folke/neoconf.nvim) (required)
- [nvzone/volt](https://github.com/nvzone/volt) (highly recommended for enhanced UI)

### Using lazy.nvim

```lua
{
  "Ajaymamtora/nvim-control-center",
  dependencies = {
    "folke/neoconf.nvim",
    "nvzone/volt", -- Optional but highly recommended
  },
  config = function()
    require("nvim-control-center").setup({
      -- Enable built-in features
      features = {
        lsp_servers = true,  -- LSP toggle tab
        formatters = true,   -- Formatter toggle tab
        tasks = true,        -- Tasks management tab
      },
      -- Your custom groups
      groups = {
        -- ...
      },
    })
  end,
}
```

## 🚀 Quick Start

```lua
require("nvim-control-center").setup({
  -- Window configuration
  window_size = {
    width = 0.8,  -- 80% of screen width
    height = 0.8, -- 80% of screen height
  },
  border = "rounded", -- "single", "double", "rounded", "solid", "shadow", or nil

  -- Title customization
  title = "My Control Center",
  title_icon = "󰢚",

  -- Enable built-in feature modules (simple)
  features = {
    lsp_servers = true,  -- Toggle LSP servers per project
    formatters = true,   -- Toggle formatters per project
    tasks = true,        -- Manage overseer.nvim tasks
  },

  -- Or with customization (table format)
  -- features = {
  --   lsp_servers = {
  --     enabled = true,
  --     label = "Language Servers",  -- Custom tab name
  --     icon = "󰒋",                   -- Custom icon
  --   },
  --   formatters = { enabled = true, label = "Code Formatters" },
  --   tasks = { enabled = true },
  -- },

  -- Volt UI options
  volt = {
    enabled = true,         -- Use volt for enhanced UI
    hover_effects = true,   -- Enable hover state highlighting
  },

  -- Define your custom setting groups
  groups = {
    {
      name = "editor",
      label = "Editor",
      icon = "",
      settings = {
        {
          name = "relative_numbers",
          label = "Relative Line Numbers",
          type = "bool",
          default = true,
          get = function() return vim.wo.relativenumber end,
          set = function(value) vim.wo.relativenumber = value end,
        },
        {
          name = "colorscheme",
          label = "Color Scheme",
          type = "select",
          options = { "tokyonight", "catppuccin", "gruvbox", "nord" },
          default = "tokyonight",
          get = function() return vim.g.colors_name end,
          set = function(value) vim.cmd("colorscheme " .. value) end,
        },
      },
    },
  },
})
```

## 📖 Usage

### Opening the Control Center

```vim
:NvimControlCenter           " Open with first tab
:NvimControlCenter editor    " Open specific tab by name
:NvimControlCenter editor 2  " Open specific tab and setting
```

Or bind it to a key:

```lua
vim.keymap.set("n", "<leader>cc", "<cmd>NvimControlCenter<cr>", { desc = "Control Center" })
```

### Navigation

- `j/k` or `↑/↓`: Navigate settings
- `h/l` or `←/→`: Switch tabs
- `<CR>`: Activate/edit setting
- `<BS>`: Previous value (for select types)
- `q` or `<Esc>`: Close

### Mouse Support

- **Click** tabs to switch
- **Click** settings to select
- **Double-click** settings to activate
- **Hover** for visual feedback

## 📚 Feature Documentation

For detailed documentation on built-in features, see:

- **[Features Overview](doc/features.md)** - How features work and how to enable them
- **[LSP Servers](doc/lsp-servers.md)** - Enable/disable LSP servers per project
- **[Formatters](doc/formatters.md)** - Enable/disable formatters per project  
- **[Tasks](doc/tasks.md)** - Manage overseer.nvim tasks with auto-run support

## ⚙️ Configuration

### Setting Types

#### Boolean

```lua
{
  name = "my_bool",
  label = "Toggle Feature",
  type = "bool",
  default = false,
  get = function() return vim.g.my_feature end,
  set = function(value) vim.g.my_feature = value end,
}
```

#### Select (Dropdown)

```lua
{
  name = "my_choice",
  label = "Choose Option",
  type = "select",
  options = { "option1", "option2", "option3" },
  default = "option1",
  set = function(value) vim.g.my_choice = value end,
}
```

#### Integer

```lua
{
  name = "my_number",
  label = "Set Number",
  type = "int",
  default = 42,
  get = function() return vim.o.tabstop end,
  set = function(value) vim.o.tabstop = value end,
}
```

#### Float

```lua
{
  name = "my_float",
  label = "Set Float",
  type = "float",
  default = 3.14,
  set = function(value) vim.g.my_float = value end,
}
```

#### String/Text

```lua
{
  name = "my_text",
  label = "Enter Text",
  type = "string",
  default = "hello",
  set = function(value) vim.g.my_text = value end,
}
```

#### Action

```lua
{
  name = "reload_config",
  label = "Reload Configuration",
  type = "action",
  icon = "󰑓",
  run = function()
    vim.cmd("source $MYVIMRC")
    vim.notify("Config reloaded!", vim.log.levels.INFO)
  end,
}
```

#### Spacer

```lua
{
  type = "spacer",
  label = "Section Header",
  icon = "➤",
  top = true,    -- Add line above
  bottom = true, -- Add line below
}
```

### Customization Options

#### Icons

```lua
icons = {
  is_true = "",      -- Checked checkbox
  is_false = "",     -- Unchecked checkbox
  is_select = "󱖫",    -- Select/dropdown
  is_int = "󰎠",       -- Integer
  is_float = "",     -- Float
  is_string = "󰬶",    -- String
  is_action = "",    -- Action button
  is_spacer = "➤",    -- Spacer
}
```

#### Persistence Options

```lua
neoconf = {
  prefix = "nvim_control_center",
  default_scope = "local",      -- "local" or "global"
  respect_dotted_name = true,   -- Treat "lsp.inlay_hint" as full path
  write_after_set = true,       -- Auto-save after changes
  read_scope = "merged",        -- "merged", "local", or "global"
}
```

#### Per-Setting Options

```lua
{
  name = "my_setting",
  path = "custom.path.in.neoconf", -- Override storage path
  scope = "global",                 -- Override default scope
  persist = false,                  -- Don't persist this setting
  break_load = true,                -- Don't auto-load on startup
}
```

### Dynamic Settings (Advanced)

For features that need to regenerate settings on each render (e.g., expandable forms), use `get_settings` instead of static `settings`:

```lua
{
  name = "dynamic_group",
  label = "Dynamic Group",
  icon = "",
  get_settings = function()
    -- Return fresh settings array on each render
    return generate_settings_dynamically()
  end,
}
```

## 🎨 Highlights

The following highlight groups are defined and can be customized:

| Group | Default Link | Description |
|-------|--------------|-------------|
| `NvimControlCenterPanel` | `NormalFloat` | Main background |
| `NvimControlCenterBorder` | `FloatBorder` | Window border |
| `NvimControlCenterTitle` | `FloatTitle` | Window title |
| `NvimControlCenterTitleIcon` | `Special` | Title icon |
| `NvimControlCenterTabActive` | `CursorLine` | Active tab |
| `NvimControlCenterTabInactive` | `NormalFloat` | Inactive tab |
| `NvimControlCenterTabHover` | `Visual` | Hovered tab |
| `NvimControlCenterLineActive` | `CursorLine` | Selected setting |
| `NvimControlCenterLineInactive` | `NormalFloat` | Unselected setting |
| `NvimControlCenterLineHover` | `Visual` | Hovered setting |
| `NvimControlCenterIconActive` | `Special` | Active icon |
| `NvimControlCenterIconInactive` | `Comment` | Inactive icon |
| `NvimControlCenterIconHover` | `Function` | Hovered icon |
| `NvimControlCenterFooterKey` | `Function` | Keybinding hints |
| `NvimControlCenterFooterText` | `Comment` | Footer text |

### Custom Highlights

```lua
highlights = {
  NvimControlCenterPanel = { bg = "#1e1e2e", fg = "#cdd6f4" },
  NvimControlCenterTabActive = { bg = "#313244", bold = true },
  -- ... more customizations
}
```

## 🏗️ Architecture

The plugin is built with a modular, volt-based architecture:

```
lua/nvim-control-center/
├── init.lua              # Plugin entry point
├── config.lua            # Configuration defaults
├── commands/init.lua     # Command registration
├── persistence/data.lua  # Neoconf integration
├── features/             # Built-in feature modules
│   ├── init.lua          # Feature loader
│   ├── lsp_servers.lua   # LSP toggle feature
│   ├── formatters.lua    # Formatter toggle feature
│   └── tasks.lua         # Tasks management feature
├── ui/
│   ├── init.lua          # Main UI controller
│   ├── state.lua         # Centralized state management
│   ├── layout.lua        # Declarative layout definitions
│   ├── components.lua    # Volt UI components (tabs, settings, footer)
│   └── highlight.lua     # Highlight group management
└── utils/init.lua        # Utility functions
```

### Volt Integration

The UI leverages [nvzone/volt](https://github.com/nvzone/volt) for:
- **Extmark-based rendering**: Efficient virtual text rendering
- **Event system**: Mouse hover and click detection
- **State management**: Centralized UI state with targeted redraws
- **Component library**: Reusable UI primitives

If volt is not available, the plugin will notify and request installation.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📝 License

MIT

## 🙏 Credits

- UI powered by [nvzone/volt](https://github.com/nvzone/volt)
- Persistence via [folke/neoconf.nvim](https://github.com/folke/neoconf.nvim)
- Inspired by [minty](https://github.com/nvzone/minty) color picker design patterns
