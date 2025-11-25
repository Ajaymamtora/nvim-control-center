-- lua/nvim-control-center/init.lua
local config = require("nvim-control-center.config")
local highlight = require("nvim-control-center.ui.highlight")
local utils = require("nvim-control-center.utils")
local commands = require("nvim-control-center.commands")

local M = {}

function M.setup(user_config)
	if user_config ~= nil then
		utils.merge(config, user_config)
	end
	-- No DB init anymore (neoconf is the storage backend)
	highlight.apply_highlights()
	commands.init()
end

return M
