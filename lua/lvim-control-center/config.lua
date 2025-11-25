-- lua/lvim-control-center/config.lua
local M = {}

-- NOTE: `save` is kept only for backward-compat comments; no longer used (no SQLite).
M = {
	save = "~/.local/share/nvim/lvim-control-center",

	-- Where/how we persist & read values via neoconf
	neoconf = {
		-- All control-center values are stored under this key unless a setting provides its own `path`
		-- e.g. "lvim_control_center.relativenumber"
		prefix = "lvim_control_center",

		-- Default write scope when saving values through neoconf.set
		--   "local"  -> <project>/.neoconf.json
		--   "global" -> stdpath("config")/neoconf.json
		default_scope = "local",

		-- If a setting name already contains dots (e.g. "lsp.inlay_hint"), treat it as a full path
		-- instead of prefixing with `prefix`.
		respect_dotted_name = true,

		-- Automatically persist after calling user `setting.set(...)`
		write_after_set = true,

		-- Default read mode when loading values (merged | local | global)
		read_scope = "merged",
	},

	window_size = {
		width = 0.8,
		height = 0.8,
	},
	border = { " ", " ", " ", " ", " ", " ", " ", " " },
	icons = {
		is_true = "",
		is_false = "",
		is_select = "󱖫",
		is_int = "󰎠",
		is_float = "",
		is_string = "󰬶",
		is_action = "",
		is_spacer = "➤",
	},
	highlights = {
		LvimControlCenterPanel = { fg = "#505067", bg = "#1a1a22" },
		LvimControlCenterSeparator = { fg = "#4a6494" },
		LvimControlCenterTabActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		LvimControlCenterTabInactive = { fg = "#505067", bg = "#1a1a22" },
		LvimControlCenterTabIconActive = { fg = "#b65252" },
		LvimControlCenterTabIconInactive = { fg = "#a26666" },
		LvimControlCenterStatusLine = { fg = "#4a6494" },
		LvimControlCenterBorder = { fg = "#4a6494", bg = "#1a1a22" },
		LvimControlCenterTitle = { fg = "#b65252", bg = "#1a1a22", bold = true },
		LvimControlCenterLineActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		LvimControlCenterLineInactive = { fg = "#505067", bg = "#1a1a22" },
		LvimControlCenterIconActive = { fg = "#b65252" },
		LvimControlCenterIconInactive = { fg = "#a26666" },
		LvimControlCenterSpacer = { fg = "#b65252" },
		LvimControlCenterSpacerIcon = { fg = "#4a6494" },
	},

	-- You pass your groups in via require("lvim-control-center").setup({ groups = { ... } })
	groups = {},
}

if M.save then
	M.save = vim.fn.expand(M.save)
end

return M
