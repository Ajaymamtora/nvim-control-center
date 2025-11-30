-- lua/nvim-control-center/ui/layout.lua
-- Declarative layout definitions for volt-based UI

local M = {}

-- Layout for the main control center window
-- Each section is a named component that can be independently redrawn
M.main = {
  { name = "header", lines = function() return require("nvim-control-center.ui.components").header() end },
  { name = "tabs", lines = function() return require("nvim-control-center.ui.components").tabs() end },
  { name = "separator", lines = function() return require("nvim-control-center.ui.components").separator() end },
  { name = "settings", lines = function() return require("nvim-control-center.ui.components").settings() end },
  { name = "footer", lines = function() return require("nvim-control-center.ui.components").footer() end },
}

return M
