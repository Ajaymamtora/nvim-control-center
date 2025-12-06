-- lua/nvim-control-center/features/formatters.lua
-- Formatter toggle feature - dynamically generates settings for each configured formatter

local M = {}

-- Get config lazily to ensure user config is merged
local function get_config()
	return require("nvim-control-center.config")
end

-- Get the neoconf path for a formatter's disabled state
local function get_formatter_path(formatter_name)
	return ("formatter.%s.disabled"):format(formatter_name)
end

-- Get all configured formatters from conform.nvim
-- Includes both available formatters and formatters marked as disabled in neoconf
local function get_configured_formatters()
	local formatters = {}
	local seen = {}

	-- Method 1: Get all formatters from conform.nvim
	local conform_ok, conform = pcall(require, "conform")
	if conform_ok and conform.list_all_formatters then
		local all_formatters = conform.list_all_formatters()
		for _, formatter_info in ipairs(all_formatters) do
			local name = formatter_info.name
			if name and not seen[name] then
				seen[name] = true
				table.insert(formatters, name)
			end
		end
	end

	-- Method 2: Include formatters marked as disabled in neoconf
	-- This ensures disabled formatters still appear so they can be re-enabled
	local neoconf_ok, neoconf = pcall(require, "neoconf")
	if neoconf_ok then
		local formatter_settings = neoconf.get("formatter", nil, { ["local"] = true, global = true })
		if type(formatter_settings) == "table" then
			for name, formatter_config in pairs(formatter_settings) do
				if type(name) == "string" and type(formatter_config) == "table" and not seen[name] then
					-- Check if this formatter entry has a disabled flag
					if formatter_config.disabled ~= nil then
						seen[name] = true
						table.insert(formatters, name)
					end
				end
			end
		end
	end

	table.sort(formatters)
	return formatters
end

-- Check if a formatter is marked as disabled in neoconf
local function is_disabled_in_neoconf(formatter_name)
	local neoconf_ok, neoconf = pcall(require, "neoconf")
	if not neoconf_ok then
		return false
	end
	local path = get_formatter_path(formatter_name)
	local disabled = neoconf.get(path, nil, { ["local"] = true, global = true })
	return disabled == true
end

-- Generate a setting definition for a formatter
local function make_formatter_setting(formatter_name)
	return {
		name = get_formatter_path(formatter_name),
		label = formatter_name,
		type = "bool",
		-- The neoconf key stores "disabled" state (true = disabled, nil = enabled)
		-- UI shows: true = tick, false = cross
		-- So we need to INVERT for display: not disabled = tick
		-- default = false because nil (enabled) should flip to true (disable)
		default = false,
		-- Skip the startup set() call in data.apply_saved_settings
		break_load = true,
		-- get() returns INVERTED for display: not disabled
		get = function()
			return not is_disabled_in_neoconf(formatter_name)
		end,
		-- set() receives the NEW "disabled" value after UI flips it
		-- true = user wants to disable, false = user wants to enable
		set = function(new_disabled_value)
			local neoconf_ok, neoconf = pcall(require, "neoconf")
			if neoconf_ok then
				local config = get_config()
				local scope = (config.neoconf and config.neoconf.default_scope) or "local"

				if new_disabled_value then
					-- Disabling: set formatter.<name>.disabled = true
					local path = get_formatter_path(formatter_name)
					neoconf.set(path, true, { scope = scope })
				else
					-- Enabling: remove the entire formatter.<name> object by setting it to nil
					local parent_path = ("formatter.%s"):format(formatter_name)
					neoconf.set(parent_path, nil, { scope = scope })
				end
			end

			-- Schedule clearing session_overrides AFTER the UI has set it
			-- This ensures our get() is used for the next redraw
			vim.schedule(function()
				local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
				if ui_state_ok and ui_state.session_overrides then
					ui_state.session_overrides[get_formatter_path(formatter_name)] = nil
				end
				-- Trigger another redraw to show correct tick/cross
				local volt_ok, volt = pcall(require, "volt")
				if volt_ok and ui_state_ok and ui_state.buf and vim.api.nvim_buf_is_valid(ui_state.buf) then
					volt.redraw(ui_state.buf, { "settings" })
				end
			end)
		end,
		persist = false,
	}
end

-- Generate the group definition with all formatters
function M.get_group()
	local formatters = get_configured_formatters()

	local settings = {}

	if #formatters == 0 then
		table.insert(settings, {
			type = "spacer",
			label = "No formatters detected",
			icon = "",
		})
	else
		for _, formatter_name in ipairs(formatters) do
			table.insert(settings, make_formatter_setting(formatter_name))
		end
	end

	return {
		name = "formatters",
		label = "Formatters",
		icon = "󰉢",
		settings = settings,
	}
end

-- Check if a formatter is disabled (for use by conform.nvim integration)
function M.is_formatter_disabled(formatter_name)
	return is_disabled_in_neoconf(formatter_name)
end

-- Apply saved formatter settings on startup (READ ONLY)
-- Note: Unlike LSP, formatters don't need to be "stopped" - they're just skipped during format
function M.apply_saved_settings()
	-- Nothing to do on startup - conform.nvim will check is_formatter_disabled() dynamically
end

-- Initialize the feature
function M.init()
	-- Nothing needed
end

return M
