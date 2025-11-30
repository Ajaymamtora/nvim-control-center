-- lua/nvim-control-center/ui/components.lua
-- Volt-based UI components for nvim-control-center

local config = require("nvim-control-center.config")
local state = require("nvim-control-center.ui.state")
local data = require("nvim-control-center.persistence.data")

local M = {}

-- Helper: Create padding string
local function pad(n)
  return string.rep(" ", n)
end

-- Helper: Get volt UI module if available
local function get_volt_ui()
  local ok, ui = pcall(require, "volt.ui")
  return ok and ui or nil
end

-- Helper: Generate a horizontal line
local function horizontal_line(char, width, hl)
  char = char or "─"
  hl = hl or "NvimControlCenterSeparator"
  return { { string.rep(char, width), hl } }
end

-----------------------------------------------------------
-- HEADER COMPONENT
-----------------------------------------------------------
function M.header()
  local lines = {}
  local title = config.title or "Control Center"
  local icon = config.title_icon or "󰢚"

  -- Title line with icon
  local title_text = icon .. " " .. title
  local title_padding = math.floor((state.width - vim.fn.strwidth(title_text)) / 2)

  table.insert(lines, {
    { pad(title_padding), "NvimControlCenterPanel" },
    { icon .. " ", "NvimControlCenterTitleIcon" },
    { title, "NvimControlCenterTitle" },
  })

  return lines
end

-----------------------------------------------------------
-- TABS COMPONENT
-----------------------------------------------------------
function M.tabs()
  local lines = {}
  local groups = config.groups or {}

  if #groups == 0 then
    return { { { "No groups configured", "Comment" } } }
  end

  local volt_ui = get_volt_ui()

  -- Build tab labels
  local tab_line = {}
  state.tab_ranges = {}
  local col = 0

  for i, group in ipairs(groups) do
    local icon = group.icon or ""
    local has_icon = icon ~= ""
    local label = group.label or group.name or ("Tab " .. i)
    local tab_text = " " .. (has_icon and (icon .. " ") or "") .. label .. " "

    local is_active = (i == state.active_tab)
    local is_hovered = (i == state.hovered_tab)

    -- Determine highlight based on state
    local tab_hl, icon_hl
    if is_active then
      tab_hl = "NvimControlCenterTabActive"
      icon_hl = "NvimControlCenterTabIconActive"
    elseif is_hovered then
      tab_hl = "NvimControlCenterTabHover"
      icon_hl = "NvimControlCenterTabIconHover"
    else
      tab_hl = "NvimControlCenterTabInactive"
      icon_hl = "NvimControlCenterTabIconInactive"
    end

    -- Store tab ranges for click detection
    local tab_start = col
    local tab_end = col + #tab_text
    table.insert(state.tab_ranges, {
      start_col = tab_start,
      end_col = tab_end,
      tab_index = i,
      active = is_active,
    })

    -- Build the tab with click action
    local click_action = function()
      -- Validate buffer is still valid before doing anything
      if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        return
      end

      if state.active_tab ~= i then
        state.active_tab = i
        state.active_row = 1
        M.refresh_settings_meta()
        local ok = pcall(require("volt").redraw, state.buf, { "tabs", "settings", "footer" })
        if not ok then
          -- Buffer might have been closed, ignore
        end
      end
    end

    local hover_action = {
      id = "tab_" .. i,
      redraw = "tabs",
      callback = function()
        -- Validate buffer is still valid
        if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
          return
        end
        state.hovered_tab = i
      end,
    }

    if has_icon then
      -- Icon part
      table.insert(tab_line, {
        " " .. icon .. " ",
        icon_hl,
        { click = click_action, hover = hover_action },
      })
      -- Label part
      table.insert(tab_line, {
        label .. " ",
        tab_hl,
        { click = click_action, hover = hover_action },
      })
    else
      table.insert(tab_line, {
        tab_text,
        tab_hl,
        { click = click_action, hover = hover_action },
      })
    end

    col = tab_end
  end

  -- Add padding to fill width
  local remaining = state.width - col
  if remaining > 0 then
    table.insert(tab_line, { pad(remaining), "NvimControlCenterPanel" })
  end

  table.insert(lines, tab_line)
  return lines
end

-----------------------------------------------------------
-- SEPARATOR COMPONENT
-----------------------------------------------------------
function M.separator()
  return { horizontal_line("─", state.width, "NvimControlCenterSeparator") }
end

-----------------------------------------------------------
-- SETTINGS LIST COMPONENT
-----------------------------------------------------------
function M.settings()
  local lines = {}
  local groups = config.groups or {}
  local group = groups[state.active_tab]

  if not group or not group.settings then
    table.insert(lines, { { pad(state.xpad) .. "No settings in this group", "Comment" } })
    return lines
  end

  local _, _, content_height = state.get_content_bounds()
  local settings = group.settings
  local meta = {}

  for i, setting in ipairs(settings) do
    local line = {}
    local setting_type = setting.type or "string"
    local is_spacer = setting_type == "spacer"
    local is_spacer_line = setting_type == "spacer_line"
    local is_active = (i == state.active_row) and not is_spacer and not is_spacer_line
    local is_hovered = (i == state.hovered_row) and not is_spacer and not is_spacer_line

    -- Handle spacer with top/bottom lines
    if is_spacer then
      if setting.top then
        table.insert(lines, { { "", "NvimControlCenterSpacerLine" } })
        table.insert(meta, { type = "spacer_line", setting = nil, row_index = #lines })
      end
    end

    -- Get current value
    local value = nil
    if not is_spacer and not is_spacer_line and setting_type ~= "action" then
      if state.session_overrides[setting.name] ~= nil then
        value = state.session_overrides[setting.name]
      elseif setting.get then
        pcall(function() value = setting.get() end)
      end
      if value == nil then
        value = data.load_setting(setting)
      end
      if value == nil and setting.default ~= nil then
        value = setting.default
      end
    end

    -- Build the line content
    local click_action = nil
    local hover_action = nil

    if not is_spacer and not is_spacer_line then
      click_action = function()
        -- Validate buffer before action
        if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
          return
        end
        -- Set active row and trigger the setting action
        state.active_row = i
        pcall(require("volt").redraw, state.buf, { "settings", "footer" })

        -- Trigger the actual setting action (toggle/edit/etc)
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(state.buf) then
            -- Get the trigger function from ui/init.lua
            local ui = require("nvim-control-center.ui")
            if ui._trigger_setting_action then
              ui._trigger_setting_action()
            end
          end
        end)
      end
      hover_action = {
        id = "setting_" .. i,
        redraw = "settings",
        callback = function()
          -- Validate buffer before hover callback
          if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
            return
          end
          state.hovered_row = i
        end,
      }
    end

    -- Determine highlights
    local line_hl, icon_hl, value_hl
    if is_spacer_line then
      line_hl = "NvimControlCenterSpacerLine"
      icon_hl = "NvimControlCenterSpacerLine"
    elseif is_spacer then
      line_hl = "NvimControlCenterSpacer"
      icon_hl = "NvimControlCenterSpacerIcon"
    elseif is_active then
      line_hl = "NvimControlCenterLineActive"
      icon_hl = "NvimControlCenterIconActive"
      value_hl = "NvimControlCenterValueActive"
    elseif is_hovered then
      line_hl = "NvimControlCenterLineHover"
      icon_hl = "NvimControlCenterIconHover"
      value_hl = "NvimControlCenterValueHover"
    else
      line_hl = "NvimControlCenterLineInactive"
      icon_hl = "NvimControlCenterIconInactive"
      value_hl = "NvimControlCenterValueInactive"
    end

    -- Build status icon
    local status_icon = " "
    if setting_type == "bool" or setting_type == "boolean" then
      -- Ensure we have a boolean value (default to false if nil)
      local bool_val = value
      if bool_val == nil then
        bool_val = false
      end
      status_icon = bool_val and config.icons.is_true or config.icons.is_false
    elseif not is_spacer and not is_spacer_line then
      status_icon = "~"
    end

    -- Build type icon
    local type_icon = setting.icon or ""
    if type_icon == "" then
      if setting_type == "select" then
        type_icon = config.icons.is_select
      elseif setting_type == "int" or setting_type == "integer" then
        type_icon = config.icons.is_int
      elseif setting_type == "float" or setting_type == "number" then
        type_icon = config.icons.is_float
      elseif setting_type == "text" or setting_type == "string" then
        type_icon = config.icons.is_string
      elseif setting_type == "action" then
        type_icon = config.icons.is_action
      elseif is_spacer then
        type_icon = config.icons.is_spacer
      end
    end

    -- Get label
    local label = setting.label or setting.desc or setting.name or ""

    if is_spacer_line then
      -- Empty spacer line
      table.insert(line, { "", "NvimControlCenterSpacerLine" })
    elseif is_spacer then
      -- Spacer row with icon and label
      if type_icon ~= "" then
        table.insert(line, { type_icon .. " ", icon_hl })
      end
      table.insert(line, { label, line_hl })
    else
      -- Regular setting row
      -- Status icon (checkbox state or ~)
      table.insert(line, { " " .. status_icon .. " ", icon_hl, { click = click_action, hover = hover_action } })

      -- Label
      table.insert(line, { label, line_hl, { click = click_action, hover = hover_action } })

      -- Type icon (after label)
      if type_icon ~= "" then
        table.insert(line, { " " .. type_icon, icon_hl, { click = click_action, hover = hover_action } })
      end

      -- Value (for non-bool types)
      if setting_type ~= "bool" and setting_type ~= "boolean" and setting_type ~= "action" then
        local val_str = ""
        if setting_type == "int" or setting_type == "integer" then
          val_str = string.format("%d", tonumber(value or 0))
        elseif setting_type == "float" or setting_type == "number" then
          val_str = tostring(value or 0)
        elseif value ~= nil then
          val_str = tostring(value)
        end
        if val_str ~= "" then
          table.insert(line, { ": ", line_hl, { click = click_action, hover = hover_action } })
          table.insert(line, { val_str, value_hl or line_hl, { click = click_action, hover = hover_action } })
        end
      end
    end

    table.insert(lines, line)
    table.insert(meta, { type = setting_type, setting = setting, row_index = #lines })

    -- Handle spacer bottom line
    if is_spacer and setting.bottom then
      table.insert(lines, { { "", "NvimControlCenterSpacerLine" } })
      table.insert(meta, { type = "spacer_line", setting = nil, row_index = #lines })
    end
  end

  -- Store meta for navigation
  state.settings_meta = meta

  -- Pad to fill content height
  local padding_needed = content_height - #lines
  for _ = 1, padding_needed do
    table.insert(lines, { { "", "NvimControlCenterPanel" } })
  end

  return lines
end

-----------------------------------------------------------
-- FOOTER COMPONENT
-----------------------------------------------------------
function M.footer()
  local lines = {}

  -- Separator line
  table.insert(lines, horizontal_line("─", state.width, "NvimControlCenterSeparator"))

  -- Get current setting type for context-aware keybindings
  local setting_type = "string"
  local meta = state.settings_meta
  if meta and meta[state.active_row] then
    setting_type = meta[state.active_row].type or "string"
  end

  -- Build keybindings help line
  local keybinds = {}

  -- Navigation
  table.insert(keybinds, { " ↑↓ ", "NvimControlCenterFooterKey" })
  table.insert(keybinds, { "Navigate ", "NvimControlCenterFooterText" })
  table.insert(keybinds, { " ←→ ", "NvimControlCenterFooterKey" })
  table.insert(keybinds, { "Tabs ", "NvimControlCenterFooterText" })
  table.insert(keybinds, { " q ", "NvimControlCenterFooterKey" })
  table.insert(keybinds, { "Close ", "NvimControlCenterFooterText" })

  -- Context-aware action
  if setting_type == "bool" or setting_type == "boolean" then
    table.insert(keybinds, { " ⏎ ", "NvimControlCenterFooterKey" })
    table.insert(keybinds, { "Toggle", "NvimControlCenterFooterText" })
  elseif setting_type == "select" then
    table.insert(keybinds, { " ⏎ ", "NvimControlCenterFooterKey" })
    table.insert(keybinds, { "Select ", "NvimControlCenterFooterText" })
    table.insert(keybinds, { " ⌫ ", "NvimControlCenterFooterKey" })
    table.insert(keybinds, { "Prev", "NvimControlCenterFooterText" })
  elseif setting_type == "action" then
    table.insert(keybinds, { " ⏎ ", "NvimControlCenterFooterKey" })
    table.insert(keybinds, { "Execute", "NvimControlCenterFooterText" })
  elseif setting_type ~= "spacer" and setting_type ~= "spacer_line" then
    table.insert(keybinds, { " ⏎ ", "NvimControlCenterFooterKey" })
    table.insert(keybinds, { "Edit", "NvimControlCenterFooterText" })
  end

  table.insert(lines, keybinds)

  return lines
end

-----------------------------------------------------------
-- HELPER: Refresh settings metadata
-----------------------------------------------------------
function M.refresh_settings_meta()
  local groups = config.groups or {}
  local group = groups[state.active_tab]
  if not group or not group.settings then
    state.settings_meta = {}
    return
  end

  local meta = {}
  for i, setting in ipairs(group.settings) do
    local setting_type = setting.type or "string"

    -- Handle spacer top line
    if setting_type == "spacer" and setting.top then
      table.insert(meta, { type = "spacer_line", setting = nil })
    end

    table.insert(meta, { type = setting_type, setting = setting })

    -- Handle spacer bottom line
    if setting_type == "spacer" and setting.bottom then
      table.insert(meta, { type = "spacer_line", setting = nil })
    end
  end

  state.settings_meta = meta

  -- Ensure active_row is valid
  if state.active_row < 1 then
    state.active_row = 1
  end
  if state.active_row > #meta then
    state.active_row = math.max(1, #meta)
  end

  -- Skip to first selectable row if current is spacer
  local m = meta[state.active_row]
  if m and (m.type == "spacer" or m.type == "spacer_line") then
    for i = state.active_row, #meta do
      if meta[i].type ~= "spacer" and meta[i].type ~= "spacer_line" then
        state.active_row = i
        break
      end
    end
  end
end

-----------------------------------------------------------
-- HELPER: Get first selectable row
-----------------------------------------------------------
function M.get_first_selectable_row()
  local meta = state.settings_meta
  if not meta or #meta == 0 then
    return 1
  end
  for i, m in ipairs(meta) do
    if m.type ~= "spacer" and m.type ~= "spacer_line" then
      return i
    end
  end
  return 1
end

return M
