-- lua/nvim-control-center/ui/init.lua
local config = require("nvim-control-center.config")
local highlight = require("nvim-control-center.ui.highlight")
local data = require("nvim-control-center.persistence.data")
local state = require("nvim-control-center.ui.state")
local components = require("nvim-control-center.ui.components")
local layout = require("nvim-control-center.ui.layout")

local M = {}

-- Check if volt is available
local volt_available = pcall(require, "volt")
local volt_events_available = pcall(require, "volt.events")

-----------------------------------------------------------
-- CORE VOLT-BASED RENDERING
-----------------------------------------------------------

local function get_win_size()
  local width = math.floor(vim.o.columns * (config.window_size and config.window_size.width or 0.8))
  local height = math.floor(vim.o.lines * (config.window_size and config.window_size.height or 0.8))
  width = math.max(width, 40)
  height = math.max(height, 12)
  return width, height
end

local function trigger_setting_action()
  local groups = config.groups or {}
  local group = groups[state.active_tab]
  if not group or (not group.settings and not group.get_settings) then
    return
  end

  local meta = state.settings_meta
  local m = meta and meta[state.active_row]
  local setting = m and m.setting

  if not setting or m.type == "spacer" or m.type == "spacer_line" then
    return
  end

  local function persist(val)
    if setting.persist == false then
      return
    end
    data.save_setting(setting, val)
  end

  local function redraw_ui()
    if volt_available then
      require("volt").redraw(state.buf, { "settings", "footer" })
    end
  end

  if setting.type == "bool" or setting.type == "boolean" then
    -- Use setting.get() if available (for dynamic settings), otherwise load from neoconf
    local value
    if type(setting.get) == "function" then
      local ok, val = pcall(setting.get)
      if ok then value = val end
    end
    if value == nil then
      value = data.load_setting(setting)
    end
    if value == nil then
      value = setting.default
    end
    value = not value
    if setting.set then
      setting.set(value, nil, state.origin_bufnr)
    end
    if (config.neoconf and config.neoconf.write_after_set) ~= false then
      persist(value)
    end
    state.session_overrides[setting.name] = value
    redraw_ui()
  elseif setting.type == "select" and setting.options then
    local current_val = data.load_setting(setting)
    if current_val == nil then
      current_val = setting.default or setting.options[1]
    end

    vim.ui.select(setting.options, {
      prompt = "Select " .. (setting.label or setting.name),
      format_item = function(item)
        if item == current_val then
          return tostring(item) .. " *"
        end
        return tostring(item)
      end,
    }, function(choice)
      if choice then
        if setting.set then
          setting.set(choice, nil, state.origin_bufnr)
        end
        if (config.neoconf and config.neoconf.write_after_set) ~= false then
          persist(choice)
        end
        state.session_overrides[setting.name] = choice
        vim.schedule(redraw_ui)
      end
    end)
  elseif setting.type == "text" or setting.type == "string" then
    local prompt = "Set " .. (setting.label or setting.name) .. ":"
    local current = data.load_setting(setting) or setting.default or ""
    vim.ui.input({ prompt = prompt, default = tostring(current) }, function(input)
      if input then
        if setting.set then
          setting.set(input, nil, state.origin_bufnr)
        end
        if (config.neoconf and config.neoconf.write_after_set) ~= false then
          persist(input)
        end
        state.session_overrides[setting.name] = input
        redraw_ui()
      end
    end)
  elseif setting.type == "int" or setting.type == "integer" then
    local prompt = "Set " .. (setting.label or setting.name) .. ":"
    local current = data.load_setting(setting) or setting.default or 0
    vim.ui.input({ prompt = prompt, default = tostring(current) }, function(input)
      if input then
        local num = tonumber(input)
        if num and math.floor(num) == num then
          if setting.set then
            setting.set(num, nil, state.origin_bufnr)
          end
          if (config.neoconf and config.neoconf.write_after_set) ~= false then
            persist(num)
          end
          state.session_overrides[setting.name] = num
          redraw_ui()
        else
          vim.notify("Please enter a valid integer!", vim.log.levels.ERROR)
        end
      end
    end)
  elseif setting.type == "float" or setting.type == "number" then
    local prompt = "Set " .. (setting.label or setting.name) .. ":"
    local current = data.load_setting(setting) or setting.default or 0
    vim.ui.input({ prompt = prompt, default = tostring(current) }, function(input)
      if input then
        local num = tonumber(input)
        if num then
          if setting.set then
            setting.set(num, nil, state.origin_bufnr)
          end
          if (config.neoconf and config.neoconf.write_after_set) ~= false then
            persist(num)
          end
          state.session_overrides[setting.name] = num
          redraw_ui()
        else
          vim.notify("Please enter a valid number!", vim.log.levels.ERROR)
        end
      end
    end)
  elseif setting.type == "array" then
    -- Toggle expand/collapse for array
    local setting_name = setting.name
    if state.expanded_arrays[setting_name] then
      state.expanded_arrays[setting_name] = nil
    else
      state.expanded_arrays[setting_name] = true
    end
    redraw_ui()
  elseif setting.type == "array_item" then
    -- Edit array item value
    local prompt = "Edit value:"
    local current = setting.item_value or ""
    vim.ui.input({ prompt = prompt, default = tostring(current) }, function(input)
      if input ~= nil then -- Allow empty string but not cancel
        if setting.set_item then
          setting.set_item(setting.item_index, input)
        end
        redraw_ui()
      end
    end)
  elseif setting.type == "array_add" then
    -- Add new array item
    vim.ui.input({ prompt = "New value: " }, function(input)
      if input ~= nil and input ~= "" then
        if setting.add_item then
          setting.add_item(input)
        end
        redraw_ui()
      end
    end)
  elseif setting.type == "array_remove" then
    -- Remove array item
    if setting.remove_item then
      setting.remove_item(setting.item_index)
    end
    redraw_ui()
  elseif setting.type == "action" then
    if setting.run and type(setting.run) == "function" then
      setting.run(state.origin_bufnr)
    else
      vim.notify("No action defined for: " .. (setting.label or setting.name), vim.log.levels.WARN)
    end
    redraw_ui()
  end
end

local function move_row(delta)
  local meta = state.settings_meta
  local count = meta and #meta or 0
  if count == 0 then
    return
  end

  local new_row = state.active_row
  repeat
    new_row = new_row + delta
  until new_row < 1
    or new_row > count
    or (meta[new_row].type ~= "spacer" and meta[new_row].type ~= "spacer_line")

  if new_row < 1 then
    new_row = components.get_first_selectable_row()
  elseif new_row > count then
    for i = count, 1, -1 do
      if meta[i].type ~= "spacer" and meta[i].type ~= "spacer_line" then
        new_row = i
        break
      end
    end
  end

  if meta[new_row] and meta[new_row].type ~= "spacer" and meta[new_row].type ~= "spacer_line" then
    state.active_row = new_row
  end

  if volt_available then
    require("volt").redraw(state.buf, { "settings", "footer" })
  end
end

local function change_tab(delta)
  local group_count = #config.groups
  if delta > 0 then
    if state.active_tab < group_count then
      state.active_tab = state.active_tab + 1
      components.refresh_settings_meta()
      state.active_row = components.get_first_selectable_row()
      if volt_available then
        require("volt").redraw(state.buf, { "tabs", "settings", "footer" })
      end
    end
  else
    if state.active_tab > 1 then
      state.active_tab = state.active_tab - 1
      components.refresh_settings_meta()
      state.active_row = components.get_first_selectable_row()
      if volt_available then
        require("volt").redraw(state.buf, { "tabs", "settings", "footer" })
      end
    end
  end
end

local function cycle_select_value(delta)
  local meta = state.settings_meta
  local m = meta and meta[state.active_row]
  local setting = m and m.setting

  if not setting or m.type ~= "select" or not setting.options then
    return
  end

  local value = data.load_setting(setting)
  if value == nil then
    value = setting.default or setting.options[1]
  end

  local idx = 1
  for i, v in ipairs(setting.options) do
    if v == value then
      idx = i
      break
    end
  end

  local new_idx = idx + delta
  if new_idx < 1 then
    new_idx = #setting.options
  elseif new_idx > #setting.options then
    new_idx = 1
  end

  local new_val = setting.options[new_idx]

  if setting.set then
    setting.set(new_val, nil, state.origin_bufnr)
  end
  if (config.neoconf and config.neoconf.write_after_set) ~= false and setting.persist ~= false then
    data.save_setting(setting, new_val)
  end

  state.session_overrides[setting.name] = new_val

  if volt_available then
    require("volt").redraw(state.buf, { "settings", "footer" })
  end
end

local function set_keymaps()
  local buf = state.buf

  -- Safe close function that prevents double-close
  local function safe_close()
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      return
    end

    -- Use vim's native window close instead of volt.close
    local wins = vim.fn.win_findbuf(buf)
    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  -- Navigation
  vim.api.nvim_buf_set_keymap(buf, "n", "j", "", {
    nowait = true,
    noremap = true,
    callback = function()
      move_row(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Down>", "", {
    nowait = true,
    noremap = true,
    callback = function()
      move_row(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "k", "", {
    nowait = true,
    noremap = true,
    callback = function()
      move_row(-1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Up>", "", {
    nowait = true,
    noremap = true,
    callback = function()
      move_row(-1)
    end,
  })

  -- Tab navigation
  vim.api.nvim_buf_set_keymap(buf, "n", "l", "", {
    nowait = true,
    noremap = true,
    callback = function()
      change_tab(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Right>", "", {
    nowait = true,
    noremap = true,
    callback = function()
      change_tab(1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "h", "", {
    nowait = true,
    noremap = true,
    callback = function()
      change_tab(-1)
    end,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Left>", "", {
    nowait = true,
    noremap = true,
    callback = function()
      change_tab(-1)
    end,
  })

  -- Close with safe handling
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    nowait = true,
    noremap = true,
    callback = safe_close,
  })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
    nowait = true,
    noremap = true,
    callback = safe_close,
  })

  -- Action trigger
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
    nowait = true,
    noremap = true,
    callback = trigger_setting_action,
  })

  -- Previous value for select
  vim.api.nvim_buf_set_keymap(buf, "n", "<BS>", "", {
    nowait = true,
    noremap = true,
    callback = function()
      cycle_select_value(-1)
    end,
  })

  -- Open local neoconf file (configurable key)
  local neoconf_key = config.keymaps and config.keymaps.neoconf_local or "e"
  vim.api.nvim_buf_set_keymap(buf, "n", neoconf_key, "", {
    nowait = true,
    noremap = true,
    callback = function()
      safe_close()
      vim.cmd("Neoconf local")
    end,
  })
end

-----------------------------------------------------------
-- MAIN OPEN FUNCTION
-----------------------------------------------------------

M.open = function(tab_selector, id_or_row)
  highlight.apply_highlights()

  -- Reset and initialize state
  state.reset()
  state.origin_bufnr = vim.api.nvim_get_current_buf()

  -- Determine active tab
  if tab_selector then
    for i, group in ipairs(config.groups) do
      if group.label == tab_selector or group.name == tab_selector then
        state.active_tab = i
        break
      end
    end
  end

  -- Validate groups
  if #config.groups == 0 then
    vim.notify("No settings groups found!", vim.log.levels.ERROR)
    return
  end

  -- Get window dimensions
  local width, height = get_win_size()
  state.width = width
  state.height = height

  -- Refresh settings metadata
  components.refresh_settings_meta()

  -- Determine active row
  if id_or_row then
    local group = config.groups[state.active_tab]
    if group and group.settings then
      for i, m in ipairs(state.settings_meta) do
        if m.type ~= "spacer" and m.type ~= "spacer_line" and m.setting then
          local idx = tonumber(id_or_row)
          if idx and i == idx then
            state.active_row = i
            break
          elseif m.setting.name == id_or_row then
            state.active_row = i
            break
          end
        end
      end
    end
  else
    state.active_row = components.get_first_selectable_row()
  end

  -- Use volt if available, fallback to native UI
  if volt_available and volt_events_available then
    M.open_with_volt()
  else
    vim.notify(
      "[nvim-control-center] volt library not found, falling back to basic UI. Install nvzone/volt for enhanced UI.",
      vim.log.levels.WARN
    )
    M.open_fallback()
  end
end

-----------------------------------------------------------
-- VOLT-BASED IMPLEMENTATION
-----------------------------------------------------------

M.open_with_volt = function()
  local volt = require("volt")
  local events = require("volt.events")

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  state.buf = buf

  -- Create namespace
  local ns = vim.api.nvim_create_namespace("nvim-control-center")
  state.ns = ns

  -- Initialize volt layout
  volt.gen_data({
    {
      buf = buf,
      xpad = state.xpad,
      ns = ns,
      layout = {
        { name = "tabs", lines = components.tabs },
        { name = "separator", lines = components.separator },
        { name = "settings", lines = components.settings },
        { name = "footer", lines = components.footer },
      },
    },
  })

  -- Open window
  local border = config.border
  if border == nil then
    border = vim.o.winborder
    if border == "" then
      border = "rounded"
    end
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = state.width,
    height = state.height,
    row = math.floor((vim.o.lines - state.height) / 2),
    col = math.floor((vim.o.columns - state.width) / 2),
    zindex = 10,
    border = border,
    style = "minimal",
    noautocmd = false,
    title = config.title or "Control Center",
    title_pos = "center",
  })
  state.win = win

  -- Set buffer options
  vim.bo[buf].filetype = "nvim-control-center"

  -- Set window highlights
  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NvimControlCenterPanel,FloatBorder:NvimControlCenterBorder,FloatTitle:NvimControlCenterTitle",
    { win = win }
  )

  -- Run volt
  volt.run(buf, {
    h = state.height,
    w = state.width,
  })

  -- Enable volt events
  events.add(buf)

  -- Setup volt mappings with proper cleanup
  volt.mappings({
    bufs = { buf },
    winclosed_event = true,
    close_func = function(closed_buf)
      if closed_buf == buf then
        -- Clean up state first
        state.reset()
      end
    end,
    after_close = function()
      -- Additional cleanup after all windows closed
      vim.schedule(function()
        -- Ensure state is fully reset
        state.reset()
      end)
    end,
  })

  -- Setup custom keymaps (in addition to volt defaults)
  set_keymaps()
end

-----------------------------------------------------------
-- FALLBACK IMPLEMENTATION (original native UI)
-----------------------------------------------------------

M.open_fallback = function()
  -- This is a simplified fallback that doesn't use volt
  -- Uses the original extmark-based approach from the old ui/init.lua

  vim.notify(
    "[nvim-control-center] Fallback UI not fully implemented. Please install nvzone/volt.",
    vim.log.levels.ERROR
  )

  -- TODO: Could implement a basic fallback if needed,
  -- but the main focus is on the volt-based UI
end

-- Expose trigger_setting_action for click handlers in components
M._trigger_setting_action = trigger_setting_action

return M
