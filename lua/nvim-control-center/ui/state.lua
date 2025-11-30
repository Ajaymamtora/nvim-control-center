-- lua/nvim-control-center/ui/state.lua
-- Centralized state management for volt-based UI

local M = {
  -- Buffer references
  buf = nil,
  win = nil,
  ns = nil,

  -- UI dimensions
  width = 60,
  height = 20,
  xpad = 0,

  -- Navigation state
  active_tab = 1,
  active_row = 1,

  -- Content cache
  settings_meta = {},
  session_overrides = {},

  -- Origin buffer (for actions that need context)
  origin_bufnr = nil,

  -- Tab click ranges for mouse support
  tab_ranges = {},

  -- Layout dimensions
  header_height = 3,
  footer_height = 2,

  -- Hover state tracking
  hovered_row = nil,
  hovered_tab = nil,
}

-- Reset state for new window
function M.reset()
  M.buf = nil
  M.win = nil
  M.ns = nil
  M.active_tab = 1
  M.active_row = 1
  M.settings_meta = {}
  M.session_overrides = {}
  M.tab_ranges = {}
  M.hovered_row = nil
  M.hovered_tab = nil
end

-- Get content area dimensions
function M.get_content_bounds()
  local content_start = M.header_height
  local content_end = M.height - M.footer_height
  local content_height = content_end - content_start
  return content_start, content_end, content_height
end

return M
