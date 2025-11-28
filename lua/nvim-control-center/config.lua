-- lua/nvim-control-center/config.lua
local M = {}

-- NOTE: `save` is kept only for backward-compat comments; no longer used (no SQLite).
M = {
	save = "~/.local/share/nvim/nvim-control-center",

	-- Where/how we persist & read values via neoconf
	neoconf = {
		-- All control-center values are stored under this key unless a setting provides its own `path`
		-- e.g. "nvim_control_center.relativenumber"
		prefix = "nvim_control_center",

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
	border = nil,
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
		NvimControlCenterPanel = { link = "NormalFloat" },
		NvimControlCenterSeparator = { link = "FloatBorder" },
		NvimControlCenterTabActive = { link = "CursorLine" },
		NvimControlCenterTabInactive = { link = "NormalFloat" },
		NvimControlCenterTabIconActive = { link = "Special" },
		NvimControlCenterTabIconInactive = { link = "Comment" },
		NvimControlCenterStatusLine = { link = "StatusLine" },
		NvimControlCenterBorder = { link = "FloatBorder" },
		NvimControlCenterTitle = { link = "FloatTitle" },
		NvimControlCenterLineActive = { link = "CursorLine" },
		NvimControlCenterLineInactive = { link = "NormalFloat" },
		NvimControlCenterIconActive = { link = "Special" },
		NvimControlCenterIconInactive = { link = "Comment" },
		NvimControlCenterSpacer = { link = "Title" },
		NvimControlCenterSpacerIcon = { link = "Constant" },
		NvimControlCenterSpacerLine = { link = "Comment" },
	},

	-- You pass your groups in via require("nvim-control-center").setup({ groups = { ... } })
	groups = {},
}

if M.save then
	M.save = vim.fn.expand(M.save)
end

return M
