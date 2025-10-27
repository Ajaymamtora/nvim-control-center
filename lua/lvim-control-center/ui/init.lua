-- lua/lvim-control-center/ui/init.lua
local config = require("lvim-control-center.config")
local highlight = require("lvim-control-center.ui.highlight")
local data = require("lvim-control-center.persistence.data")

local M = {}

local function render_setting_line(setting, value)
	local label = setting.label or setting.desc or setting.name
	local t = setting.type
	if t == "bool" or t == "boolean" then
		return string.format(" %s %s", value and config.icons.is_true or config.icons.is_false, label)
	elseif t == "select" then
		return string.format(" %s %s: %s", config.icons.is_select, label, value ~= nil and tostring(value) or "")
	elseif t == "int" or t == "integer" then
		return string.format(" %s %s: %d", config.icons.is_int, label, tonumber(value or 0))
	elseif t == "float" or t == "number" then
		return string.format(" %s %s: %s", config.icons.is_float, label, value ~= nil and tostring(value) or "0")
	elseif t == "action" then
		return string.format(" %s %s", config.icons.is_action or "", label)
	else
		return string.format(" %s %s: %s", config.icons.is_string, label, value ~= nil and tostring(value) or "")
	end
end

local function get_settings_lines(group)
	local lines = {}
	if group and group.settings then
		for _, setting in ipairs(group.settings) do
			local value
			if setting.type == "action" then
				value = nil
			elseif setting.get then
				pcall(function()
					value = setting.get()
				end)
			end
			if value == nil and setting.type ~= "action" then
				value = data.load_setting(setting)
			end
			if value == nil and setting.default ~= nil and setting.type ~= "action" then
				value = setting.default
			end
			local line = render_setting_line(setting, value)
			table.insert(lines, line)
		end
	end
	return lines
end

local function get_keybindings_line(setting_type)
	local base_bindings = "↑↓/jk: Navigate  ←→/hl: Change Tab  Esc/q: Close"
	local action_bindings = "  Enter: Execute"
	local edit_bindings = "  Enter: Edit"
	local toggle_bindings = "  Enter: Toggle"
	local select_bindings = "  Enter: Next Value  BS: Prev Value"

	if setting_type == "bool" or setting_type == "boolean" then
		return base_bindings .. toggle_bindings
	elseif setting_type == "select" then
		return base_bindings .. select_bindings
	elseif
		setting_type == "int"
		or setting_type == "integer"
		or setting_type == "float"
		or setting_type == "number"
		or setting_type == "text"
		or setting_type == "string"
	then
		return base_bindings .. edit_bindings
	elseif setting_type == "action" then
		return base_bindings .. action_bindings
	else
		return base_bindings .. edit_bindings
	end
end

local function apply_cursor_blending(win)
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local augroup_name = "LvimControlCenterCursorBlend"
	local cursor_blend_augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })
	vim.cmd("hi Cursor blend=100")
	vim.api.nvim_create_autocmd({ "WinLeave", "WinEnter" }, {
		group = cursor_blend_augroup,
		callback = function()
			local current_event_win = vim.api.nvim_get_current_win()
			local blend_value = current_event_win == win and 100 or 0
			vim.cmd("hi Cursor blend=" .. blend_value)
		end,
	})
end

M.open = function(tab_selector, id_or_row)
	highlight.apply_highlights()

	local origin_bufnr = vim.api.nvim_get_current_buf()

	local active_tab = 1
	if tab_selector then
		for i, group in ipairs(config.groups) do
			if group.label == tab_selector or group.name == tab_selector then
				active_tab = i
				break
			end
		end
	end

	local group = config.groups[active_tab]
	local active_setting_row = 1
	if id_or_row and group and group.settings then
		local idx = tonumber(id_or_row)
		if idx and group.settings[idx] then
			active_setting_row = idx
		else
			for i, setting in ipairs(group.settings) do
				if setting.name == id_or_row then
					active_setting_row = i
					break
				end
			end
		end
	end

	local group_count = #config.groups
	if group_count == 0 then
		vim.notify("No settings groups found!", vim.log.levels.ERROR)
		return
	end

	local function get_win_size()
		local width = math.floor(vim.o.columns * (config.window_size and config.window_size.width or 0.6))
		local height = math.floor(vim.o.lines * (config.window_size and config.window_size.height or 0.5))
		width = math.max(width, 30)
		height = math.max(height, 8)
		return width, height
	end

	local width, height = get_win_size()
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		zindex = 10,
		border = config.border or "single",
		style = "minimal",
		noautocmd = true,
	})
	_G.LVIM_CONTROL_CENTER_WIN = win

	vim.bo[buf].filetype = "lvim-control-center"

	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:LvimControlCenterPanel,FloatBorder:LvimControlCenterBorder,Title:LvimControlCenterTitle",
		{ win = win }
	)

	apply_cursor_blending(win)

	vim.wo[win].scrolloff = 0
	local header_height = 2
	local footer_height = 1
	local content_start_line = header_height
	local content_end_line = height - footer_height - 1
	local content_height = content_end_line - content_start_line + 1

	-- Store tab ranges for mouse click detection
	local tab_ranges = {}

	local function draw()
		vim.bo[buf].modifiable = true
		local lines = {}
		local tabs = {}
		tab_ranges = {} -- Reset tab ranges
		local col = 0

		for i, group_iter in ipairs(config.groups) do
			local icon = group_iter.icon or ""
			local has_icon = icon ~= ""
			local tab_label = group_iter.label or group_iter.name
			local name = " " .. icon .. (has_icon and " " or "") .. tab_label .. " "
			table.insert(tabs, name)

			local tab_start_col = col
			local tab_end_col = col + #name
			local icon_start_col = has_icon and (tab_start_col + 1) or -1
			local icon_end_col = has_icon and (icon_start_col + #icon) or -1

			table.insert(tab_ranges, {
				active = (i == active_tab),
				tab_start_col = tab_start_col,
				tab_end_col = tab_end_col,
				icon_start_col = icon_start_col,
				icon_end_col = icon_end_col,
				has_icon = has_icon,
				tab_index = i,
			})
			col = tab_end_col
		end

		local tabs_line = table.concat(tabs, "")
		table.insert(lines, tabs_line)

		local sep = string.rep("─", width)
		table.insert(lines, sep)

		local current_group = config.groups[active_tab]
		local content_lines = get_settings_lines(current_group)

		for _, l in ipairs(content_lines) do
			table.insert(lines, l)
		end

		local padding_lines_needed = math.max(0, content_height - #content_lines)
		for _ = 1, padding_lines_needed do
			table.insert(lines, "")
		end

		local setting_type = "string"
		if current_group and current_group.settings and current_group.settings[active_setting_row] then
			setting_type = current_group.settings[active_setting_row].type or "string"
		end

		table.insert(lines, get_keybindings_line(setting_type))

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		local ns_id = vim.api.nvim_create_namespace("lvim-control-center-tabs")
		vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

		local sep_byte_len = #sep
		vim.api.nvim_buf_set_extmark(buf, ns_id, 1, 0, {
			end_col = sep_byte_len,
			hl_group = "LvimControlCenterSeparator",
		})

		for _, r in ipairs(tab_ranges) do
			local tab_hl = r.active and "LvimControlCenterTabActive" or "LvimControlCenterTabInactive"
			local icon_hl = r.active and "LvimControlCenterTabIconActive" or "LvimControlCenterTabIconInactive"

			vim.api.nvim_buf_set_extmark(buf, ns_id, 0, r.tab_start_col, {
				end_col = r.tab_end_col,
				hl_group = tab_hl,
				priority = 80,
			})

			if r.has_icon then
				vim.api.nvim_buf_set_extmark(buf, ns_id, 0, r.icon_start_col, {
					end_col = r.icon_end_col,
					hl_group = icon_hl,
					priority = 90,
				})
			end
		end

		for i, line in ipairs(content_lines) do
			if i <= content_height then
				local line_index = i + header_height - 1
				local is_active = (active_setting_row == i)
				local icon_hl = is_active and "LvimControlCenterIconActive" or "LvimControlCenterIconInactive"
				local line_hl = is_active and "LvimControlCenterLineActive" or "LvimControlCenterLineInactive"

				local icon_len = 2
				if icon_len > 0 then
					vim.api.nvim_buf_set_extmark(buf, ns_id, line_index, 0, {
						end_col = icon_len,
						hl_group = icon_hl,
						priority = 100,
					})
				end

				local text_byte_len = #line
				if text_byte_len > 0 then
					vim.api.nvim_buf_set_extmark(buf, ns_id, line_index, 0, {
						end_col = text_byte_len,
						hl_group = line_hl,
						priority = 90,
						hl_mode = "blend",
					})
				end

				local disp = vim.fn.strdisplaywidth(line)
				local fill = math.max(0, width - disp)
				if fill > 0 then
					local fill_spaces = string.rep(" ", fill)
					vim.api.nvim_buf_set_extmark(buf, ns_id, line_index, text_byte_len, {
						virt_text = { { fill_spaces, line_hl } },
						virt_text_win_col = disp,
						priority = 90,
						hl_mode = "blend",
					})
				end
			end
		end

		local footer_line_index = #lines - 1
		vim.api.nvim_buf_set_extmark(buf, ns_id, footer_line_index, 0, {
			end_col = #lines[#lines],
			hl_group = "LvimControlCenterStatusLine",
			priority = 100,
		})

		local target_row = content_start_line + active_setting_row - 1
		vim.api.nvim_win_set_cursor(win, { target_row, 0 })

		vim.api.nvim_set_option_value("scrolloff", header_height, { win = win })
		vim.api.nvim_set_option_value("sidescrolloff", 0, { win = win })
		vim.api.nvim_set_option_value("scrolloff", header_height, { win = win })

		vim.bo[buf].modifiable = false
	end

	local function trigger_setting_action()
		local group_cr = config.groups[active_tab]
		local setting = group_cr.settings and group_cr.settings[active_setting_row]
		if not setting then
			return
		end

		local function persist(val)
			if setting.persist == false then
				return
			end
			data.save_setting(setting, val)
		end

		if setting.type == "bool" or setting.type == "boolean" then
			local value = data.load_setting(setting)
			if value == nil then
				value = setting.default
			end
			value = not value
			if setting.set then
				setting.set(value, nil, origin_bufnr)
			end
			if (config.neoconf and config.neoconf.write_after_set) ~= false then
				persist(value)
			end
			draw()
		elseif setting.type == "select" and setting.options then
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
			local next_val = setting.options[(idx % #setting.options) + 1]
			if setting.set then
				setting.set(next_val, nil, origin_bufnr)
			end
			if (config.neoconf and config.neoconf.write_after_set) ~= false then
				persist(next_val)
			end
			draw()
		elseif setting.type == "text" or setting.type == "string" then
			local prompt = "Set " .. (setting.label or setting.name) .. ":"
			local current = data.load_setting(setting) or setting.default or ""
			vim.ui.input({ prompt = prompt, default = tostring(current) }, function(input)
				if input then
					if setting.set then
						setting.set(input, nil, origin_bufnr)
					end
					if (config.neoconf and config.neoconf.write_after_set) ~= false then
						persist(input)
					end
					draw()
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
							setting.set(num, nil, origin_bufnr)
						end
						if (config.neoconf and config.neoconf.write_after_set) ~= false then
							persist(num)
						end
						draw()
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
							setting.set(num, nil, origin_bufnr)
						end
						if (config.neoconf and config.neoconf.write_after_set) ~= false then
							persist(num)
						end
						draw()
					else
						vim.notify("Please enter a valid number!", vim.log.levels.ERROR)
					end
				end
			end)
		elseif setting.type == "action" then
			if setting.run and type(setting.run) == "function" then
				setting.run(origin_bufnr)
			else
				vim.notify("No action defined for: " .. (setting.label or setting.name), vim.log.levels.WARN)
			end
			draw()
		end
	end

	local function set_keymaps()
		local function move_row(delta)
			local group_move = config.groups[active_tab]
			local count = #(group_move.settings or {})
			if count == 0 then
				return
			end
			active_setting_row = math.max(1, math.min(count, active_setting_row + delta))
			draw()
		end

		local function change_tab(delta)
			if delta > 0 then
				if active_tab < group_count then
					active_tab = active_tab + 1
					active_setting_row = 1
					draw()
				end
			else
				if active_tab > 1 then
					active_tab = active_tab - 1
					active_setting_row = 1
					draw()
				end
			end
		end

		-- Move down (j and Down arrow)
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

		-- Move up (k and Up arrow)
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

		-- Change tab right (l and Right arrow)
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

		-- Change tab left (h and Left arrow)
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

		vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
			nowait = true,
			noremap = true,
			callback = function()
				vim.api.nvim_win_close(win, true)
			end,
		})

		vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
			nowait = true,
			noremap = true,
			callback = function()
				vim.api.nvim_win_close(win, true)
			end,
		})

		vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", "", {
			nowait = true,
			noremap = true,
			callback = trigger_setting_action,
		})

		vim.api.nvim_buf_set_keymap(buf, "n", "<BS>", "", {
			nowait = true,
			noremap = true,
			callback = function()
				local group_bs = config.groups[active_tab]
				local setting = group_bs.settings and group_bs.settings[active_setting_row]

				if not setting or setting.type ~= "select" or not setting.options then
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

				local prev_idx = idx - 1
				if prev_idx < 1 then
					prev_idx = #setting.options
				end

				local prev_val = setting.options[prev_idx]

				if setting.set then
					setting.set(prev_val, nil, origin_bufnr)
				end
				if (config.neoconf and config.neoconf.write_after_set) ~= false and setting.persist ~= false then
					data.save_setting(setting, prev_val)
				end

				draw()
			end,
		})

		-- Mouse support
		vim.api.nvim_buf_set_keymap(buf, "n", "<LeftMouse>", "", {
			nowait = true,
			noremap = true,
			callback = function()
				local mouse_pos = vim.fn.getmousepos()
				local click_line = mouse_pos.line
				local click_col = mouse_pos.column - 1 -- 0-indexed

				-- Check if clicking on tabs (line 1, 0-indexed line 0)
				if click_line == 1 then
					for _, tab_range in ipairs(tab_ranges) do
						if click_col >= tab_range.tab_start_col and click_col < tab_range.tab_end_col then
							if active_tab ~= tab_range.tab_index then
								active_tab = tab_range.tab_index
								active_setting_row = 1
								draw()
							end
							return
						end
					end
				end

				-- Check if clicking on a setting row
				local current_group = config.groups[active_tab]
				if current_group and current_group.settings then
					local content_lines = get_settings_lines(current_group)
					local setting_row = click_line - header_height

					if setting_row >= 1 and setting_row <= #content_lines then
						active_setting_row = setting_row
						draw()
					end
				end
			end,
		})

		-- Double-click to activate setting
		vim.api.nvim_buf_set_keymap(buf, "n", "<2-LeftMouse>", "", {
			nowait = true,
			noremap = true,
			callback = function()
				local mouse_pos = vim.fn.getmousepos()
				local click_line = mouse_pos.line
				local click_col = mouse_pos.column - 1

				-- Check if clicking on tabs
				if click_line == 1 then
					for _, tab_range in ipairs(tab_ranges) do
						if click_col >= tab_range.tab_start_col and click_col < tab_range.tab_end_col then
							if active_tab ~= tab_range.tab_index then
								active_tab = tab_range.tab_index
								active_setting_row = 1
								draw()
							end
							return
						end
					end
				end

				-- Check if clicking on a setting row
				local current_group = config.groups[active_tab]
				if current_group and current_group.settings then
					local content_lines = get_settings_lines(current_group)
					local setting_row = click_line - header_height

					if setting_row >= 1 and setting_row <= #content_lines then
						active_setting_row = setting_row
						trigger_setting_action()
					end
				end
			end,
		})
	end

	set_keymaps()
	draw()
end

return M
