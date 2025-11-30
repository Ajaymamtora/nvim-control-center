-- lua/nvim-control-center/config.lua

-- Default configuration (immutable)
local defaults = {
  save = "~/.local/share/nvim/nvim-control-center",

  -- Where/how we persist & read values via neoconf
  neoconf = {
    -- All control-center values are stored under this key unless a setting provides its own `path`
    -- e.g. "nvim_control_center.relativenumber"
    prefix = "nvim_control_center",

    -- Default write scope when saving values through neoconf.set
    --   "local"  -> <project>/.neoconf.json
    --   "global" -> stdpath("config")/neoconf.json
    default_scope = "local",

    -- If a setting name already contains dots (e.g. "lsp.inlay_hint"), treat it as a full path
    -- instead of prefixing with `prefix`.
    respect_dotted_name = true,

    -- Automatically persist after calling user `setting.set(...)`
    write_after_set = true,

    -- Default read mode when loading values (merged | local | global)
    read_scope = "merged",
  },

  window_size = {
    width = 0.8,
    height = 0.8,
  },
  border = nil,

  -- Title customization
  title = nil, -- Set to customize title (default: "Control Center")
  title_icon = nil, -- Set to customize title icon (default: "󰢚")

  icons = {
    is_true = "",
    is_false = "",
    is_select = "󱖫",
    is_int = "󰎠",
    is_float = "",
    is_string = "󰬶",
    is_action = "",
    is_spacer = "➤",
  },

  -- Volt UI options
  volt = {
    enabled = true, -- Set to false to force fallback to native UI (not recommended)
    hover_effects = true, -- Enable hover state highlighting
    smooth_scroll = false, -- Reserved for future smooth scrolling feature
    animations = false, -- Reserved for future animation support
  },

  highlights = {
    -- Window background and borders
    NvimControlCenterPanel = { link = "NormalFloat" },
    NvimControlCenterBorder = { link = "FloatBorder" },
    NvimControlCenterTitle = { link = "FloatTitle" },
    NvimControlCenterTitleIcon = { link = "Special" },
    NvimControlCenterSeparator = { link = "FloatBorder" },

    -- Tab highlights
    NvimControlCenterTabActive = { link = "CursorLine" },
    NvimControlCenterTabInactive = { link = "NormalFloat" },
    NvimControlCenterTabHover = { link = "Visual" },
    NvimControlCenterTabIconActive = { link = "Special" },
    NvimControlCenterTabIconInactive = { link = "Comment" },
    NvimControlCenterTabIconHover = { link = "Function" },

    -- Setting line highlights
    NvimControlCenterLineActive = { link = "CursorLine" },
    NvimControlCenterLineInactive = { link = "NormalFloat" },
    NvimControlCenterLineHover = { link = "Visual" },

    -- Icon highlights
    NvimControlCenterIconActive = { link = "Special" },
    NvimControlCenterIconInactive = { link = "Comment" },
    NvimControlCenterIconHover = { link = "Function" },

    -- Value highlights
    NvimControlCenterValueActive = { link = "String" },
    NvimControlCenterValueInactive = { link = "Comment" },
    NvimControlCenterValueHover = { link = "String" },

    -- Spacer highlights
    NvimControlCenterSpacer = { link = "Title" },
    NvimControlCenterSpacerIcon = { link = "Constant" },
    NvimControlCenterSpacerLine = { link = "Comment" },

    -- Footer highlights
    NvimControlCenterFooterKey = { link = "Function" },
    NvimControlCenterFooterText = { link = "Comment" },

    -- Legacy (kept for backward compatibility)
    NvimControlCenterStatusLine = { link = "StatusLine" },
  },

  -- You pass your groups in via require("nvim-control-center").setup({ groups = { ... } })
  groups = {},
}

-- Runtime configuration (starts as a copy of defaults, gets merged with user config)
local M = vim.deepcopy(defaults)

if M.save then
  M.save = vim.fn.expand(M.save)
end

-- Export defaults for reference (useful for resetting or documentation)
M._defaults = defaults

return M
