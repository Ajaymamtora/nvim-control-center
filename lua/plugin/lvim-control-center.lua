-- lua/plugin/lvim-control-center.lua
if vim.fn.has("nvim-0.10.0") == 0 then
	print("Lvim Control Center requires Neovim >= 0.10.0")
	return
end

if vim.g.loaded_lvim_control_center then
	return
end
vim.g.loaded_lvim_control_center = true

-- Hard dependency on neoconf
local has_neoconf = pcall(require, "neoconf")
if not has_neoconf then
	vim.schedule(function()
		vim.notify("[lvim-control-center] Please install folke/neoconf.nvim", vim.log.levels.ERROR)
	end)
	return
end

-- Boot the plugin with defaults; users can call setup() themselves from their config to pass groups/options.
pcall(function()
	require("lvim-control-center").setup({})
end)
