-- lua/lvim-control-center/persistence/data.lua
local config = require("lvim-control-center.config")

local M = {}

local function with_neoconf()
	local ok, neoconf = pcall(require, "neoconf")
	if not ok then
		vim.schedule(function()
			vim.notify("[lvim-control-center] Missing dependency: folke/neoconf.nvim", vim.log.levels.ERROR)
		end)
		return nil
	end
	return neoconf
end

local function resolve_path(setting_or_name)
	local cfg = config.neoconf or {}
	local prefix = cfg.prefix or "lvim_control_center"

	if type(setting_or_name) == "table" then
		local s = setting_or_name
		-- If an explicit path is provided, use it
		if type(s.path) == "string" and s.path ~= "" then
			return s.path
		end
		local name = s.name or ""
		-- By default, use the name directly at top level (no prefix)
		-- Only add prefix if explicitly requested via respect_dotted_name = false
		if cfg.respect_dotted_name == false then
			return ("%s.%s"):format(prefix, name)
		end
		return name
	else
		local name = tostring(setting_or_name or "")
		-- By default, use the name directly at top level (no prefix)
		-- Only add prefix if explicitly requested via respect_dotted_name = false
		if cfg.respect_dotted_name == false then
			return ("%s.%s"):format(prefix, name)
		end
		return name
	end
end

local function resolve_write_scope(setting)
	local default_scope = (config.neoconf and config.neoconf.default_scope) or "local"
	return (type(setting) == "table" and (setting.scope or default_scope)) or default_scope
end

local function read_opts_for(scope)
	if scope == "local" then
		return { ["local"] = true, global = false }
	elseif scope == "global" then
		return { ["local"] = false, global = true }
	end
	-- merged (default)
	return { ["local"] = true, global = true }
end

local function resolve_read_scope(setting)
	local rs = type(setting) == "table" and setting.read_scope or nil
	return rs or (config.neoconf and config.neoconf.read_scope) or "merged"
end

-- Public API (new): save/load with full setting metadata (respects .path/.scope)
function M.save_setting(setting, value)
	local neoconf = with_neoconf()
	if not neoconf then
		return false
	end
	local path = resolve_path(setting)
	local scope = resolve_write_scope(setting)
	local ok, err = neoconf.set(path, value, { scope = scope })
	if not ok then
		if err then
			vim.notify(
				("[lvim-control-center] Failed to save %s: %s"):format(path, tostring(err)),
				vim.log.levels.ERROR
			)
		end
		return false
	end
	return true
end

function M.load_setting(setting)
	local neoconf = with_neoconf()
	if not neoconf then
		return nil
	end
	local path = resolve_path(setting)
	local read_scope = resolve_read_scope(setting)
	local opts = read_opts_for(read_scope)
	local val = neoconf.get(path, nil, opts)
	return val
end

-- Backward-compatible helpers (when only a plain name is provided)
M.save = function(name, value)
	return M.save_setting({ name = name }, value)
end

M.load = function(name)
	return M.load_setting({ name = name })
end

-- Apply persisted values on startup (calls user `setting.set(value, true)`)
M.apply_saved_settings = function()
	for _, group in ipairs(config.groups or {}) do
		for _, setting in ipairs(group.settings or {}) do
			if not setting.break_load then
				local value = M.load_setting(setting)
				if value == nil then
					value = setting.default
				end
				if value ~= nil and type(setting.set) == "function" then
					pcall(setting.set, value, true)
				end
			end
		end
	end
end

return M
