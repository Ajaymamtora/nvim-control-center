-- lua/nvim-control-center/features/lsp_servers.lua
-- LSP Server toggle feature - dynamically generates settings for each configured LSP

local M = {}

-- Get config lazily to ensure user config is merged
local function get_config()
	return require("nvim-control-center.config")
end

-- Get the neoconf path for an LSP server's disabled state
local function get_lsp_path(lsp_name)
	return ("lsp.%s.disabled"):format(lsp_name)
end

-- Get all configured LSP servers
local function get_configured_servers()
	local servers = {}
	local seen = {}

	if vim.lsp._enabled_configs and type(vim.lsp._enabled_configs) == "table" then
		for name, _ in pairs(vim.lsp._enabled_configs) do
			if type(name) == "string" and not seen[name] then
				seen[name] = true
				table.insert(servers, name)
			end
		end
	end

	local lsp_config = rawget(vim.lsp, "config")
	if lsp_config and type(lsp_config) == "table" then
		pcall(function()
			for name, _ in pairs(lsp_config) do
				if type(name) == "string" and not name:match("^_") and not seen[name] then
					seen[name] = true
					table.insert(servers, name)
				end
			end
		end)
	end

	if #servers == 0 then
		local clients = vim.lsp.get_clients()
		for _, client in ipairs(clients) do
			if client.name and not seen[client.name] then
				seen[client.name] = true
				table.insert(servers, client.name)
			end
		end
	end

	table.sort(servers)
	return servers
end

-- Check if a server is marked as disabled in neoconf
local function is_disabled_in_neoconf(lsp_name)
	local neoconf_ok, neoconf = pcall(require, "neoconf")
	if not neoconf_ok then
		return false
	end
	local path = get_lsp_path(lsp_name)
	local disabled = neoconf.get(path, nil, { ["local"] = true, global = true })
	return disabled == true
end

-- Generate a setting definition for an LSP server
local function make_lsp_setting(lsp_name)
	return {
		name = get_lsp_path(lsp_name),
		label = lsp_name,
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
			return not is_disabled_in_neoconf(lsp_name)
		end,
		-- set() receives the NEW "disabled" value after UI flips it
		-- true = user wants to disable, false = user wants to enable
		set = function(new_disabled_value)
			local neoconf_ok, neoconf = pcall(require, "neoconf")
			if neoconf_ok then
				local config = get_config()
				local scope = (config.neoconf and config.neoconf.default_scope) or "local"

				if new_disabled_value then
					-- Disabling: set lsp.<name>.disabled = true
					local path = get_lsp_path(lsp_name)
					neoconf.set(path, true, { scope = scope })
				else
					-- Enabling: remove the entire lsp.<name> object by setting it to nil
					local parent_path = ("lsp.%s"):format(lsp_name)
					neoconf.set(parent_path, nil, { scope = scope })
				end
			end

			-- Enable/disable the LSP and handle running clients
			local enabled = not new_disabled_value
			vim.lsp.enable(lsp_name, enabled)

			if enabled then
				-- When enabling, trigger LSP to attach to matching buffers
				-- by triggering FileType event on current buffer
				local bufnr = vim.api.nvim_get_current_buf()
				local ft = vim.bo[bufnr].filetype
				if ft and ft ~= "" then
					vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
				end
			else
				-- When disabling, stop all running clients for this LSP
				local clients = vim.lsp.get_clients({ name = lsp_name })
				for _, client in ipairs(clients) do
					vim.lsp.stop_client(client.id, true) -- force=true for immediate stop
				end
			end

			-- Schedule clearing session_overrides AFTER the UI has set it
			-- This ensures our get() is used for the next redraw
			vim.schedule(function()
				local ui_state_ok, ui_state = pcall(require, "nvim-control-center.ui.state")
				if ui_state_ok and ui_state.session_overrides then
					ui_state.session_overrides[get_lsp_path(lsp_name)] = nil
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

-- Generate the group definition with all LSP servers
function M.get_group()
	local servers = get_configured_servers()

	local settings = {}

	if #servers == 0 then
		table.insert(settings, {
			type = "spacer",
			label = "No LSP servers detected",
			icon = "",
		})
	else
		for _, server_name in ipairs(servers) do
			table.insert(settings, make_lsp_setting(server_name))
		end
	end

	return {
		name = "lsp_servers",
		label = "LSP Servers",
		icon = "",
		settings = settings,
	}
end

-- Apply saved LSP settings on startup (READ ONLY)
function M.apply_saved_settings()
	local servers = get_configured_servers()

	for _, server_name in ipairs(servers) do
		if is_disabled_in_neoconf(server_name) then
			vim.lsp.enable(server_name, false)
		end
	end
end

-- Initialize the feature
function M.init()
	-- Nothing needed
end

return M
