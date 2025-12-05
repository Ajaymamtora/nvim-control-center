-- lua/nvim-control-center/init.lua
local config = require("nvim-control-center.config")
local highlight = require("nvim-control-center.ui.highlight")
local utils = require("nvim-control-center.utils")
local commands = require("nvim-control-center.commands")
local features = require("nvim-control-center.features")

local M = {}

function M.setup(user_config)
	if user_config ~= nil then
		utils.merge(config, user_config)
	end

	-- Initialize enabled features
	features.init()

	-- Append feature-generated groups to user groups
	local feature_groups = features.get_groups()
	for _, group in ipairs(feature_groups) do
		table.insert(config.groups, group)
	end

	-- No DB init anymore (neoconf is the storage backend)
	highlight.apply_highlights()
	commands.init()
end

return M
