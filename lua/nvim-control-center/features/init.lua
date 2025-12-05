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
}

-- Loaded feature instances
local loaded_features = {}

-- Initialize enabled features based on config
function M.init()
	loaded_features = {}
	local config = get_config()
	local features_config = config.features or {}

	for feature_name, module_path in pairs(feature_modules) do
		if features_config[feature_name] then
			local ok, feature_module = pcall(require, module_path)
			if ok and feature_module then
				loaded_features[feature_name] = feature_module
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
	for _, feature in pairs(loaded_features) do
		if feature.get_group then
			local group = feature.get_group()
			if group then
				table.insert(groups, group)
			end
		end
	end
	return groups
end

-- Apply saved settings from all features
function M.apply_saved_settings()
	for _, feature in pairs(loaded_features) do
		if feature.apply_saved_settings then
			feature.apply_saved_settings()
		end
	end
end

return M
