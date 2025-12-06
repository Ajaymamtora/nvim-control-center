-- lua/nvim-control-center/features/init.lua
-- Feature module loader for plugin-generated functionality

local M = {}

-- Get config lazily to ensure user config is merged
local function get_config()
	return require("nvim-control-center.config")
end

-- Registry of available feature modules
local feature_modules = {
	lsp_servers = "nvim-control-center.features.lsp_servers",
	formatters = "nvim-control-center.features.formatters",
	tasks = "nvim-control-center.features.tasks",
}

-- Loaded feature instances with their configs
local loaded_features = {}

-- Normalize feature config: converts true to { enabled = true }
local function normalize_feature_config(config_value)
	if config_value == true then
		return { enabled = true }
	elseif type(config_value) == "table" then
		-- Ensure enabled is set (default to true if table given but enabled not specified)
		if config_value.enabled == nil then
			config_value.enabled = true
		end
		return config_value
	end
	return nil
end

-- Initialize enabled features based on config
function M.init()
	loaded_features = {}
	local config = get_config()
	local features_config = config.features or {}

	for feature_name, module_path in pairs(feature_modules) do
		local feature_config = normalize_feature_config(features_config[feature_name])

		if feature_config and feature_config.enabled then
			local ok, feature_module = pcall(require, module_path)
			if ok and feature_module then
				loaded_features[feature_name] = {
					module = feature_module,
					config = feature_config, -- Store user overrides (label, icon)
				}
				if feature_module.init then
					feature_module.init()
				end
			else
				vim.schedule(function()
					vim.notify(
						("[nvim-control-center] Failed to load feature: %s"):format(feature_name),
						vim.log.levels.ERROR
					)
				end)
			end
		end
	end
end

-- Get all groups from enabled features
-- @return table[] List of group definitions to append to config.groups
function M.get_groups()
	local groups = {}
	for _, feature_data in pairs(loaded_features) do
		local feature = feature_data.module
		local user_config = feature_data.config or {}

		if feature.get_group then
			local group = feature.get_group(user_config)
			if group then
				-- Apply user overrides for label and icon
				if user_config.label then
					group.label = user_config.label
				end
				if user_config.icon then
					group.icon = user_config.icon
				end
				table.insert(groups, group)
			end
		end
	end
	return groups
end

-- Apply saved settings from all features
function M.apply_saved_settings()
	for _, feature_data in pairs(loaded_features) do
		local feature = feature_data.module
		if feature.apply_saved_settings then
			feature.apply_saved_settings()
		end
	end
end

return M
