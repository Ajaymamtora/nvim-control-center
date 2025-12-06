-- lua/nvim-control-center/features/tasks.lua
-- Overseer Tasks management feature - displays and manages tasks from neoconf.json

local M = {}

-- State for expanded task editing
local expanded_task_index = nil -- Which task is currently expanded for editing
local original_task_state = nil -- Original state for rollback
local expanded_env_task_index = nil -- Which task's env vars section is expanded

-- Helper: trigger UI redraw
local function redraw_ui()
	vim.schedule(function()
		local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
		local volt_ok, volt = pcall(require, "volt")
		if volt_ok and ui_state_ok and ui_state.buf and vim.api.nvim_buf_is_valid(ui_state.buf) then
			volt.redraw(ui_state.buf, { "settings" })
		end
	end)
end

-- Get config lazily to ensure user config is merged
local function get_config()
	return require("nvim-control-center.config")
end

-- Read tasks array from neoconf
local function get_tasks_from_neoconf()
	local neoconf_ok, neoconf = pcall(require, "neoconf")
	if not neoconf_ok then
		return {}
	end

	local tasks = neoconf.get("tasks", nil, { ["local"] = true, global = true })
	if type(tasks) ~= "table" then
		return {}
	end

	return tasks
end

-- Save entire tasks array to neoconf
local function save_tasks_to_neoconf(tasks)
	local neoconf_ok, neoconf = pcall(require, "neoconf")
	if not neoconf_ok then
		return false
	end

	local config = get_config()
	local scope = (config.neoconf and config.neoconf.default_scope) or "local"
	neoconf.set("tasks", tasks, { scope = scope })
	return true
end

-- Update a single task in neoconf by index
local function update_task_in_neoconf(index, task)
	local tasks = get_tasks_from_neoconf()
	tasks[index] = task
	return save_tasks_to_neoconf(tasks)
end

-- Delete a task from neoconf by index
local function delete_task_from_neoconf(index)
	local tasks = get_tasks_from_neoconf()
	table.remove(tasks, index)
	return save_tasks_to_neoconf(tasks)
end

-- Determine if a task is a template reference or a full inline definition
local function is_template_task(task)
	if task.type == "template" then
		return true
	end
	if not task.cmd or task.cmd == "" then
		return true
	end
	return false
end

-- Run a task - either as template lookup or as inline definition
local function run_task(task_index)
	local overseer_ok, overseer = pcall(require, "overseer")
	if not overseer_ok then
		vim.notify("overseer.nvim is not available", vim.log.levels.ERROR)
		return
	end

	local tasks = get_tasks_from_neoconf()
	local task = tasks[task_index]
	if not task then
		vim.notify("Task not found", vim.log.levels.ERROR)
		return
	end

	if not task.name or task.name == "" then
		vim.notify("Task has no name", vim.log.levels.ERROR)
		return
	end

	-- Close the control center window before running task
	local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
	if ui_state_ok and ui_state.win and vim.api.nvim_win_is_valid(ui_state.win) then
		pcall(vim.api.nvim_win_close, ui_state.win, true)
	end

	if is_template_task(task) then
		vim.notify("Running template task: " .. task.name, vim.log.levels.INFO)
		overseer.run_task({
			name = task.name,
			autostart = true,
		})
	else
		local task_def = {
			name = task.name,
			cmd = task.cmd,
			args = task.args,
			cwd = task.cwd,
			env = task.env,
		}

		-- Handle auto_restart by setting up restart on exit
		if task.auto_restart then
			task_def.on_exit = function(_, return_val)
				vim.schedule(function()
					vim.notify("Restarting task: " .. task.name, vim.log.levels.INFO)
					run_task(task_index)
				end)
			end
		end

		local new_task = overseer.new_task(task_def)
		new_task:start()
		vim.notify("Started task: " .. task.name .. (task.auto_restart and " (auto-restart)" or ""), vim.log.levels.INFO)
	end
end

-- Toggle task expansion for editing
local function toggle_task_edit(index)
	local tasks = get_tasks_from_neoconf()
	local task = tasks[index]
	if not task then
		return
	end

	if expanded_task_index == index then
		-- Collapse: already expanded, close it
		expanded_task_index = nil
		original_task_state = nil
	else
		-- Expand: save original state for rollback and expand
		expanded_task_index = index
		original_task_state = vim.deepcopy(task)
	end
	redraw_ui()
end

-- Rollback task to original state
local function rollback_task(index)
	if original_task_state and expanded_task_index == index then
		update_task_in_neoconf(index, original_task_state)
		vim.notify("Reverted changes to: " .. (original_task_state.name or "unnamed"), vim.log.levels.INFO)
		expanded_task_index = nil
		original_task_state = nil
		redraw_ui()
	end
end

-- Close expanded edit (save and close)
local function close_task_edit(index)
	if expanded_task_index == index then
		expanded_task_index = nil
		original_task_state = nil
		vim.notify("Changes saved", vim.log.levels.INFO)
		redraw_ui()
	end
end

-- Create editable field setting for a task property
local function make_task_field_setting(task, index, field_name, label, icon)
	return {
		name = "task_" .. index .. "_field_" .. field_name,
		label = "    " .. (icon or "") .. " " .. label,
		type = "text",
		default = "",
		get = function()
			-- Re-read from neoconf for fresh value
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			if t and t[field_name] then
				local val = t[field_name]
				if type(val) == "table" then
					return table.concat(val, " ")
				end
				return tostring(val)
			end
			return ""
		end,
		set = function(val)
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			if t then
				if val == "" then
					t[field_name] = nil
				else
					t[field_name] = val
				end
				save_tasks_to_neoconf(tasks)
			end
		end,
		persist = false,
	}
end

-- Create type selector for task (template vs inline)
local function make_task_type_setting(task, index)
	return {
		name = "task_" .. index .. "_field_type",
		label = "    󰊕 Type",
		type = "select",
		options = { "inline", "template" },
		default = "template",
		get = function()
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			if not t then
				return "template"
			end
			-- Use is_template_task logic: explicit type OR no cmd means template
			if is_template_task(t) then
				return "template"
			end
			return "inline"
		end,
		set = function(val)
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			if t then
				if val == "template" then
					t.type = "template"
				else
					t.type = nil -- inline is default, don't store
				end
				save_tasks_to_neoconf(tasks)
			end
		end,
		persist = false,
	}
end

-- Create setting definition for a single task
local function make_task_settings(task, index)
	local settings = {}
	local is_expanded = (expanded_task_index == index)

	-- Task header with name and start mode selector
	local start_options = { "auto", "once", "disabled" }
	local expand_icon = is_expanded and "▼" or "▶"

	table.insert(settings, {
		name = "task_" .. index .. "_header",
		label = expand_icon .. " " .. (task.name or ("Task " .. index)),
		type = "select",
		options = start_options,
		default = "disabled",
		get = function()
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			return (t and t.start) or "disabled"
		end,
		set = function(val)
			local tasks = get_tasks_from_neoconf()
			local t = tasks[index]
			if t then
				t.start = val
				save_tasks_to_neoconf(tasks)
			end
		end,
		persist = false,
	})

	-- Action row: Run, Edit, Delete
	table.insert(settings, {
		name = "task_" .. index .. "_run",
		label = "  ► Run",
		type = "action",
		run = function()
			run_task(index)
		end,
	})

	table.insert(settings, {
		name = "task_" .. index .. "_edit",
		label = is_expanded and "  ▲ Collapse" or "  ✎ Edit",
		type = "action",
		run = function()
			toggle_task_edit(index)
		end,
	})

	table.insert(settings, {
		name = "task_" .. index .. "_delete",
		label = "  ✕ Delete",
		type = "action",
		run = function()
			vim.ui.select({ "Yes", "No" }, {
				prompt = "Delete task '" .. (task.name or "unnamed") .. "'?",
			}, function(choice)
				if choice == "Yes" then
					-- Collapse if expanded
					if expanded_task_index == index then
						expanded_task_index = nil
						original_task_state = nil
					end
					delete_task_from_neoconf(index)
					vim.notify("Deleted task: " .. (task.name or "unnamed"), vim.log.levels.INFO)
					redraw_ui()
				end
			end)
		end,
	})

	-- If expanded, show editable fields
	if is_expanded then
		table.insert(settings, {
			type = "spacer",
			label = "  ─── Edit Fields ───",
		})

		-- Name field
		table.insert(settings, make_task_field_setting(task, index, "name", "Name", "󰏫"))

		-- Type selector (template vs inline)
		table.insert(settings, make_task_type_setting(task, index))

		-- Command field
		table.insert(settings, make_task_field_setting(task, index, "cmd", "Command", ""))

		-- CWD field
		table.insert(settings, make_task_field_setting(task, index, "cwd", "Working Dir", ""))

		-- Args field (as space-separated string)
		table.insert(settings, make_task_field_setting(task, index, "args", "Arguments", ""))

		-- Auto-restart toggle (boolean)
		table.insert(settings, {
			name = "task_" .. index .. "_field_auto_restart",
			label = "    󰑓 Auto Restart",
			type = "bool",
			default = false,
			get = function()
				local tasks = get_tasks_from_neoconf()
				local t = tasks[index]
				return t and t.auto_restart == true
			end,
			set = function(val)
				local tasks = get_tasks_from_neoconf()
				local t = tasks[index]
				if t then
					if val then
						t.auto_restart = true
					else
						t.auto_restart = nil -- Remove if false
					end
					save_tasks_to_neoconf(tasks)
				end
				redraw_ui()
			end,
			persist = false,
		})

		-- Environment variables header (expandable)
		local is_env_expanded = (expanded_env_task_index == index)
		local env_count = 0
		if task.env and type(task.env) == "table" then
			for _ in pairs(task.env) do
				env_count = env_count + 1
			end
		end

		local env_icon = is_env_expanded and "▼" or "▶"
		local env_label = "    " .. env_icon .. " 󰒓 Env Variables"
		if env_count > 0 then
			env_label = env_label .. " (" .. env_count .. ")"
		end

		table.insert(settings, {
			name = "task_" .. index .. "_env_toggle",
			label = env_label,
			type = "action",
			run = function()
				if expanded_env_task_index == index then
					expanded_env_task_index = nil
				else
					expanded_env_task_index = index
				end
				redraw_ui()
			end,
		})

		-- If env section is expanded, show individual env vars
		if is_env_expanded then
			table.insert(settings, {
				type = "spacer",
				label = "      ─── Environment ───",
			})

			-- List each env var with edit/delete
			if task.env and type(task.env) == "table" then
				local sorted_keys = {}
				for k in pairs(task.env) do
					table.insert(sorted_keys, k)
				end
				table.sort(sorted_keys)

				for _, key in ipairs(sorted_keys) do
					local value = task.env[key]
					-- Show env var as editable text field
					table.insert(settings, {
						name = "task_" .. index .. "_env_" .. key,
						label = "       " .. key,
						type = "text",
						default = "",
						get = function()
							local tasks = get_tasks_from_neoconf()
							local t = tasks[index]
							return (t and t.env and t.env[key]) or ""
						end,
						set = function(val)
							local tasks = get_tasks_from_neoconf()
							local t = tasks[index]
							if t then
								if not t.env then
									t.env = {}
								end
								if val == "" then
									t.env[key] = nil
									-- Remove env table if empty
									if next(t.env) == nil then
										t.env = nil
									end
								else
									t.env[key] = val
								end
								save_tasks_to_neoconf(tasks)
							end
							redraw_ui()
						end,
						persist = false,
					})

					-- Delete button for this env var
					table.insert(settings, {
						name = "task_" .. index .. "_env_delete_" .. key,
						label = "        ✕ Remove " .. key,
						type = "action",
						run = function()
							local tasks = get_tasks_from_neoconf()
							local t = tasks[index]
							if t and t.env then
								t.env[key] = nil
								if next(t.env) == nil then
									t.env = nil
								end
								save_tasks_to_neoconf(tasks)
								vim.notify("Removed: " .. key, vim.log.levels.INFO)
							end
							redraw_ui()
						end,
					})
				end
			end

			-- Add new env var action
			table.insert(settings, {
				name = "task_" .. index .. "_env_add",
				label = "       + Add Variable",
				type = "action",
				run = function()
					vim.ui.input({ prompt = "Variable name (e.g. NODE_ENV): " }, function(name)
						if not name or name == "" then
							return
						end
						vim.ui.input({ prompt = "Value for " .. name .. ": " }, function(value)
							if value == nil then
								return
							end
							local tasks = get_tasks_from_neoconf()
							local t = tasks[index]
							if t then
								if not t.env then
									t.env = {}
								end
								t.env[name] = value
								save_tasks_to_neoconf(tasks)
								vim.notify("Added: " .. name .. "=" .. value, vim.log.levels.INFO)
							end
							redraw_ui()
						end)
					end)
				end,
			})

			table.insert(settings, {
				type = "spacer",
				label = "      ───────────────────",
			})
		end

		-- Action: Rollback changes
		table.insert(settings, {
			name = "task_" .. index .. "_rollback",
			label = "    ↩ Revert Changes",
			type = "action",
			run = function()
				rollback_task(index)
			end,
		})

		-- Action: Done editing
		table.insert(settings, {
			name = "task_" .. index .. "_done",
			label = "    ✓ Done Editing",
			type = "action",
			run = function()
				close_task_edit(index)
			end,
		})

		table.insert(settings, {
			type = "spacer",
			label = "  ─────────────────",
		})
	end

	return settings
end

-- Add a new task
local function add_new_task()
	vim.ui.input({ prompt = "Task name: " }, function(name)
		if not name or name == "" then
			return
		end

		local new_task = {
			name = name,
			start = "disabled",
		}

		local tasks = get_tasks_from_neoconf()
		table.insert(tasks, new_task)
		save_tasks_to_neoconf(tasks)

		vim.notify("Created task: " .. name .. " (click Edit to configure)", vim.log.levels.INFO)

		-- Auto-expand the new task for editing
		expanded_task_index = #tasks + 1 -- Will be correct after redraw
		original_task_state = vim.deepcopy(new_task)

		redraw_ui()
	end)
end

-- Generate settings dynamically (called on each render)
local function generate_settings()
	local tasks = get_tasks_from_neoconf()
	local settings = {}

	if #tasks == 0 then
		table.insert(settings, {
			type = "spacer",
			label = "No tasks configured",
			icon = "",
		})
	else
		for index, task in ipairs(tasks) do
			local task_settings = make_task_settings(task, index)
			for _, setting in ipairs(task_settings) do
				table.insert(settings, setting)
			end

			-- Add separator between tasks (except after last one)
			if index < #tasks and expanded_task_index ~= index then
				table.insert(settings, {
					type = "spacer",
					label = "",
				})
			end
		end
	end

	-- Add "New Task" action at the end
	table.insert(settings, {
		type = "spacer",
		label = "",
	})
	table.insert(settings, {
		name = "task_add_new",
		label = "+ Add New Task",
		type = "action",
		run = add_new_task,
	})

	return settings
end

-- Generate the group definition with dynamic settings
function M.get_group()
	return {
		name = "tasks",
		label = "Tasks",
		icon = "",
		get_settings = generate_settings, -- Dynamic: regenerates on each render
	}
end

-- Apply saved task settings on startup
function M.apply_saved_settings()
	-- We don't auto-start here - the user's utils/overseer.lua handles that
end

-- Initialize the feature
function M.init()
	-- Reset expansion state
	expanded_task_index = nil
	original_task_state = nil
end

return M
