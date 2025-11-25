-- lua/nvim-control-center/ui/init.lua
local config = require("nvim-control-center.config")
local highlight = require("nvim-control-center.ui.highlight")
local data = require("nvim-control-center.persistence.data")

local M = {}

local function render_setting_line(setting, value)
	local label = setting.label or setting.desc or setting.name
	local t = setting.type

	local icon = setting.icon
	if not icon then
		if t == "bool" or t == "boolean" then
			icon = value and config.icons.is_true or config.icons.is_false
		elseif t == "select" then
			icon = config.icons.is_select
		elseif t == "int" or t == "integer" then
			icon = config.icons.is_int
		elseif t == "float" or t == "number" then
			icon = config.icons.is_float
		elseif t == "action" then
			icon = config.icons.is_action or ""
		elseif t == "spacer" then
			icon = config.icons.is_spacer or ""
		else
			icon = config.icons.is_string
		end
	end

	if t == "bool" or t == "boolean" then
		return string.format(" %s %s", icon, label)
	elseif t == "select" then
		return string.format(" %s %s: %s", icon, label, value ~= nil and tostring(value) or "")
	elseif t == "int" or t == "integer" then
		return string.format(" %s %s: %d", icon, label, tonumber(value or 0))
	elseif t == "float" or t == "number" then
		return string.format(" %s %s: %s", icon, label, value ~= nil and tostring(value) or "0")
	elseif t == "action" then
		return string.format(" %s %s", icon, label)
	elseif t == "spacer" then
		local spacer_text = setting.label or setting.desc or ""
		return string.format(" %s %s", icon, spacer_text)
	elseif t == "spacer_line" then
		return ""
	else
		return string.format(" %s %s: %s", icon, label, value ~= nil and tostring(value) or "")
	end
end

local function get_settings_lines(group, overrides)
	local lines = {}
	local meta = {}
	if group and group.settings then
		for _, setting in ipairs(group.settings) do
			if setting.type == "spacer" then
				if setting.top == nil then
					setting.top = false
				end
				if setting.bottom == nil then
					setting.bottom = false
				end
				if setting.top then
					table.insert(lines, render_setting_line({ type = "spacer_line" }, nil))
					table.insert(meta, { type = "spacer_line" })
				end
				local value = nil
				local line = render_setting_line(setting, value)
				table.insert(lines, line)
				table.insert(meta, { type = "spacer", setting = setting })
				if setting.bottom then
					table.insert(lines, render_setting_line({ type = "spacer_line" }, nil))
					table.insert(meta, { type = "spacer_line" })
				end
			else
				local value
				if overrides and overrides[setting.name] ~= nil then
					value = overrides[setting.name]
				elseif setting.type == "action" then
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
				table.insert(meta, { type = setting.type, setting = setting })
			end
		end
	end
	return lines, meta
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
	elseif setting_type == "spacer" or setting_type == "spacer_line" then
		return base_bindings
	else
		return base_bindings .. edit_bindings
	end
end

local function apply_cursor_blending(win)
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end

	local augroup_name = "NvimControlCenterCursorBlend"
	local cursor_blend_augroup = vim.api.nvim_create_augroup(augroup_name, { clear = true })

	local function set_cursor_blend(value)
		pcall(function()
			vim.cmd("hi Cursor blend=" .. value)
		end)
	end

	vim.api.nvim_create_autocmd("WinEnter", {
		group = cursor_blend_augroup,
		callback = function()
			if vim.api.nvim_get_current_win() == win then
				set_cursor_blend(100)
			else
				set_cursor_blend(0)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "WinLeave", "WinClosed" }, {
		group = cursor_blend_augroup,
		callback = function()
			set_cursor_blend(0)
		end,
	})

	vim.api.nvim_create_autocmd("CmdlineEnter", {
		group = cursor_blend_augroup,
		callback = function()
			set_cursor_blend(0)
		end,
	})

	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = cursor_blend_augroup,
		callback = function()
			if vim.api.nvim_get_current_win() == win then
				set_cursor_blend(100)
			else
				set_cursor_blend(0)
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = cursor_blend_augroup,
		buffer = vim.api.nvim_win_get_buf(win),
		callback = function()
			if vim.api.nvim_get_current_win() == win then
				set_cursor_blend(100)
			end
		end,
	})

	if vim.api.nvim_get_current_win() == win then
		set_cursor_blend(100)
	end
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
	local function get_first_selectable_setting_row(meta)
		if not meta then
			return 1
		end
		for i, m in ipairs(meta) do
			if m.type ~= "spacer" and m.type ~= "spacer_line" then
				return i
			end
		end
		return 1
	end
	
	local session_overrides = {}

	local content_lines, meta = get_settings_lines(group, session_overrides)
	local active_setting_row = get_first_selectable_setting_row(meta)
	if id_or_row and group and group.settings then
		for i, m in ipairs(meta) do
			local s = m.setting
			if m.type ~= "spacer" and m.type ~= "spacer_line" then
				local idx = tonumber(id_or_row)
				if idx and i == idx then
					active_setting_row = i
					break
				elseif s and s.name == id_or_row then
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

	local border = config.border
	if border == nil then
		border = vim.o.winborder
		if border == "" then
			border = "none"
		end
	end

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		zindex = 10,
		border = border,
		style = "minimal",
		noautocmd = false,
	})
	_G.NVIM_CONTROL_CENTER_WIN = win

	vim.bo[buf].filetype = "nvim-control-center"

	vim.api.nvim_set_option_value(
		"winhighlight",
		"Normal:NvimControlCenterPanel,FloatBorder:NvimControlCenterBorder,Title:NvimControlCenterTitle",
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
		content_lines, meta = get_settings_lines(current_group, session_overrides)

		for _, l in ipairs(content_lines) do
			table.insert(lines, l)
		end

		local padding_lines_needed = math.max(0, content_height - #content_lines)
		for _ = 1, padding_lines_needed do
			table.insert(lines, "")
		end

		local setting_type = "string"
		if meta and meta[active_setting_row] then
			setting_type = meta[active_setting_row].type or "string"
		end

		table.insert(lines, get_keybindings_line(setting_type))

		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

		local ns_id = vim.api.nvim_create_namespace("nvim-control-center-tabs")
		vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

		local sep_byte_len = #sep
		vim.api.nvim_buf_set_extmark(buf, ns_id, 1, 0, {
			end_col = sep_byte_len,
			hl_group = "NvimControlCenterSeparator",
		})

		for _, r in ipairs(tab_ranges) do
			local tab_hl = r.active and "NvimControlCenterTabActive" or "NvimControlCenterTabInactive"
			local icon_hl = r.active and "NvimControlCenterTabIconActive" or "NvimControlCenterTabIconInactive"

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
				local m = meta and meta[i]
				local is_spacer = m and m.type == "spacer"
				local is_spacer_line = m and m.type == "spacer_line"
				local is_active = (active_setting_row == i) and not is_spacer and not is_spacer_line
				local icon_hl = is_spacer and "NvimControlCenterSpacerIcon"
					or is_spacer_line and "NvimControlCenterSpacerLine"
					or (is_active and "NvimControlCenterIconActive" or "NvimControlCenterIconInactive")
				local line_hl = is_spacer and "NvimControlCenterSpacer"
					or is_spacer_line and "NvimControlCenterSpacerLine"
					or (is_active and "NvimControlCenterLineActive" or "NvimControlCenterLineInactive")

				local icon_len = 0
				if is_spacer then
					icon_len = #(config.icons.is_spacer or " ")
				elseif is_spacer_line then
					icon_len = 0
				else
					icon_len = 2
				end
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
			hl_group = "NvimControlCenterStatusLine",
			priority = 100,
		})

		local function get_cursor_row()
			if not meta then
				return content_start_line
			end
			if
				meta[active_setting_row]
				and meta[active_setting_row].type ~= "spacer"
				and meta[active_setting_row].type ~= "spacer_line"
			then
				return content_start_line + active_setting_row - 1
			end
			for i = active_setting_row + 1, #meta do
				if meta[i].type ~= "spacer" and meta[i].type ~= "spacer_line" then
					return content_start_line + i - 1
				end
			end
			for i = active_setting_row - 1, 1, -1 do
				if meta[i].type ~= "spacer" and meta[i].type ~= "spacer_line" then
					return content_start_line + i - 1
				end
			end
			return content_start_line
		end

		vim.api.nvim_win_set_cursor(win, { get_cursor_row(), 0 })

		vim.api.nvim_set_option_value("scrolloff", header_height, { win = win })
		vim.api.nvim_set_option_value("sidescrolloff", 0, { win = win })
		vim.api.nvim_set_option_value("scrolloff", header_height, { win = win })

		pcall(function()
			vim.cmd("hi Cursor blend=100")
		end)

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
			session_overrides[setting.name] = value
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
			session_overrides[setting.name] = next_val
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
					session_overrides[setting.name] = input
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
						session_overrides[setting.name] = num
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
						session_overrides[setting.name] = num
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

	local function move_row(delta)
		local count = meta and #meta or 0
		if count == 0 then
			return
		end
		local new_row = active_setting_row
		repeat
			new_row = new_row + delta
		until new_row < 1 or new_row > count or (meta[new_row].type ~= "spacer" and meta[new_row].type ~= "spacer_line")
		if new_row < 1 then
			new_row = get_first_selectable_setting_row(meta)
		elseif new_row > count then
			for i = count, 1, -1 do
				if meta[i].type ~= "spacer" and meta[i].type ~= "spacer_line" then
					new_row = i
					break
				end
			end
		end
		if meta[new_row] and meta[new_row].type ~= "spacer" and meta[new_row].type ~= "spacer_line" then
			active_setting_row = new_row
		end
		draw()
	end

	local function set_keymaps()
		local function change_tab(delta)
			if delta > 0 then
				if active_tab < group_count then
					active_tab = active_tab + 1
					content_lines, meta = get_settings_lines(config.groups[active_tab], session_overrides)
					active_setting_row = get_first_selectable_setting_row(meta)
					draw()
				end
			else
				if active_tab > 1 then
					active_tab = active_tab - 1
					content_lines, meta = get_settings_lines(config.groups[active_tab], session_overrides)
					active_setting_row = get_first_selectable_setting_row(meta)
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
				local m = meta and meta[active_setting_row]
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

				session_overrides[setting.name] = prev_val
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
					local content_lines = get_settings_lines(current_group, session_overrides)
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
					local content_lines = get_settings_lines(current_group, session_overrides)
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
