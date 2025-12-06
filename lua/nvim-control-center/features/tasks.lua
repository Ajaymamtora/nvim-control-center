-- lua/nvim-control-center/features/tasks.lua
-- Overseer Tasks management feature - displays and manages tasks from neoconf.json

local M = {}

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

-- Run a task using overseer.new_task for persistence
local function run_task(task_index)
	local overseer_ok, overseer = pcall(require, "overseer")
	if not overseer_ok then
		vim.notify("overseer.nvim is not available", vim.log.levels.ERROR)
		return
	end

	-- Re-read task from neoconf to get latest state
	local tasks = get_tasks_from_neoconf()
	local task = tasks[task_index]
	if not task then
		vim.notify("Task not found", vim.log.levels.ERROR)
		return
	end

	-- Check if cmd is defined
	if not task.cmd or task.cmd == "" then
		vim.notify("No command defined for task: " .. (task.name or "unnamed"), vim.log.levels.ERROR)
		return
	end

	-- Build task definition for overseer
	local task_def = {
		name = task.name,
		cmd = task.cmd,
		args = task.args,
		cwd = task.cwd,
		env = task.env,
	}

	local new_task = overseer.new_task(task_def)
	new_task:start()
	vim.notify("Started task: " .. task.name, vim.log.levels.INFO)
end

-- Edit a task via vim.ui.input prompts
local function edit_task(index, task)
	local fields = { "name", "cmd", "cwd" }
	local current_field = 1

	local function prompt_next_field()
		if current_field > #fields then
			-- All fields done, save the task
			update_task_in_neoconf(index, task)
			vim.notify("Task updated: " .. task.name, vim.log.levels.INFO)

			-- Trigger UI redraw
			vim.schedule(function()
				local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
				local volt_ok, volt = pcall(require, "volt")
				if volt_ok and ui_state_ok and ui_state.buf and vim.api.nvim_buf_is_valid(ui_state.buf) then
					volt.redraw(ui_state.buf, { "settings" })
				end
			end)
			return
		end

		local field = fields[current_field]
		local current_value = task[field] or ""
		if type(current_value) == "table" then
			current_value = table.concat(current_value, " ")
		end

		vim.ui.input({
			prompt = field:sub(1, 1):upper() .. field:sub(2) .. ": ",
			default = current_value,
		}, function(value)
			if value ~= nil then
				if value == "" then
					task[field] = nil
				else
					task[field] = value
				end
			end
			current_field = current_field + 1
			prompt_next_field()
		end)
	end

	prompt_next_field()
end

-- Create setting definition for a single task
local function make_task_settings(task, index)
	local settings = {}

	-- Task name with start mode selector
	local start_options = { "auto", "once", "disabled" }

	table.insert(settings, {
		name = "task_" .. index .. "_start",
		label = task.name or ("Task " .. index),
		type = "select",
		options = start_options,
		default = "disabled",
		get = function()
			return task.start or "disabled"
		end,
		set = function(val)
			task.start = val
			update_task_in_neoconf(index, task)
		end,
		persist = false,
	})

	-- Action: Run Now
	table.insert(settings, {
		name = "task_" .. index .. "_run",
		label = "  ► Run",
		type = "action",
		run = function()
			run_task(index)
		end,
	})

	-- Action: Edit
	table.insert(settings, {
		name = "task_" .. index .. "_edit",
		label = "  ✎ Edit",
		type = "action",
		run = function()
			edit_task(index, vim.deepcopy(task))
		end,
	})

	-- Action: Delete
	table.insert(settings, {
		name = "task_" .. index .. "_delete",
		label = "  ✕ Delete",
		type = "action",
		run = function()
			vim.ui.select({ "Yes", "No" }, {
				prompt = "Delete task '" .. (task.name or "unnamed") .. "'?",
			}, function(choice)
				if choice == "Yes" then
					delete_task_from_neoconf(index)
					vim.notify("Deleted task: " .. (task.name or "unnamed"), vim.log.levels.INFO)

					-- Trigger UI redraw
					vim.schedule(function()
						local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
						local volt_ok, volt = pcall(require, "volt")
						if volt_ok and ui_state_ok and ui_state.buf and vim.api.nvim_buf_is_valid(ui_state.buf) then
							volt.redraw(ui_state.buf, { "settings" })
						end
					end)
				end
			end)
		end,
	})

	return settings
end

-- Add a new task
local function add_new_task()
	vim.ui.input({ prompt = "Task name: " }, function(name)
		if not name or name == "" then
			return
		end

		vim.ui.input({ prompt = "Command (optional): " }, function(cmd)
			local new_task = {
				name = name,
				start = "disabled",
			}
			if cmd and cmd ~= "" then
				new_task.cmd = cmd
			end

			local tasks = get_tasks_from_neoconf()
			table.insert(tasks, new_task)
			save_tasks_to_neoconf(tasks)

			vim.notify("Created task: " .. name, vim.log.levels.INFO)

			-- Trigger UI redraw
			vim.schedule(function()
				local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
				local volt_ok, volt = pcall(require, "volt")
				if volt_ok and ui_state_ok and ui_state.buf and vim.api.nvim_buf_is_valid(ui_state.buf) then
					volt.redraw(ui_state.buf, { "settings" })
				end
			end)
		end)
	end)
end

-- Generate the group definition with all tasks
function M.get_group()
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
			if index < #tasks then
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

	return {
		name = "tasks",
		label = "Tasks",
		icon = "",
		settings = settings,
	}
end

-- Apply saved task settings on startup
-- This calls the user's existing auto-start logic
function M.apply_saved_settings()
	-- We don't auto-start here - the user's utils/overseer.lua handles that
	-- via persisted.nvim integration
end

-- Initialize the feature
function M.init()
	-- Nothing needed
end

return M
