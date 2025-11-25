# NVIM CONTROL CENTER

[License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)(https://opensource.org/licenses/MIT)

**`Nvim Control Center`** is an elegant and easy-to-configure settings management panel for Neovim. It provides a centralized user interface for quickly changing frequently used options, which are persisted across sessions.

## ✨ Features

- **Intuitive UI:** An easy-to-navigate panel with tabs (groups).
- **Jump-to-anywhere:** Instantly open the panel to a specific tab or even a specific setting by name or by row number.
- **Persistence:** Settings are automatically saved to an SQLite database and loaded on startup.
- **Easy Configuration:** Define your own settings and groups using simple Lua tables.
- **Extensibility:** Complete freedom to define complex `set` functions to manage any aspect of Neovim.
- **Type Support:** Supports boolean (`bool`/`boolean`), integer (`int`/`integer`), float/number (`float`/`number`), text (`string`/`text`), and selection (`select`) options.
- **Customization:** Easily change the appearance, such as window size, borders, dimensions, and colors.

## 📋 Requirements

- Neovim >= 0.10.0
- [kkharji/sqlite.lua](https://github.com/kkharji/sqlite.lua) - For settings persistence.
- [Ajaymamtora/neoconf.nvim](https://github.com/Ajaymamtora/neoconf.nvim) - A fork of folke/neoconf.nvim needed for persistence support.

## 💾 Installation

It's recommended to use [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
-- lazy.nvim
return {
	{
		"lvim-tech/nvim-control-center",
		dependencies = {
			"kkharji/sqlite.lua",
			"Ajaymamtora/neoconf.nvim",
		},
		config = function()
			-- Configuration goes here, see the section below
			require("nvim-control-center").setup({
				-- ...
			})
		end,
	},
}
```

## 🚀 Usage

### Open the panel

```vim
:NvimControlCenter
```

### Jump directly to a tab or setting!

- Open directly to a tab by name/label:
    ```vim
    :NvimControlCenter general -- name
    :NvimControlCenter General -- label
    ```
- Open directly to a setting by name (second param is setting's `name`):
    ```vim
    :NvimControlCenter lsp codelens
    ```
- Open directly to a setting by its row (as shown in the UI):

    ```vim
    :NvimControlCenter lsp 2
    ```

- You can also open from Lua:
    ````lua
    require("nvim-control-center.ui").open("lsp", "codelens") -- by name
    require("nvim-control-center.ui").open("lsp", 2) -- by row (number)
      ```
    ````

### Navigation

- `j` / `k`: Move up/down between settings.
- `h` / `l`: Switch between tabs (groups).
- `<CR>` (Enter): Change the selected setting.
- `<BS>`: Cycle select settings backward.
- `<Esc>`, `q`: Close the panel.

## ⚙️ Configuration

The configuration is passed to the `setup()` function. The most important part is defining the `groups`.

### Default Configuration

This is the default configuration. You can override any of these fields in your own setup:

```lua
{
	save = "~/.local/share/nvim/nvim-control-center",
	window_size = {
		width = 0.8,
		height = 0.8,
	},
	window_size = {
		width = 0.8,
		height = 0.8,
	},
	border = nil, -- Defaults to vim.o.winborder, or "none" if empty.
	icons = {
		is_true = "",
	icons = {
		is_true = "",
		is_false = "",
		is_select = "󱖫",
		is_int = "󰎠",
		is_float = "",
		is_string = "󰬶",
	},
	highlights = {
		NvimControlCenterPanel = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterSeparator = { fg = "#4a6494" },
		NvimControlCenterTabActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		NvimControlCenterTabInactive = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterTabIconActive = { fg = "#b65252" },
		NvimControlCenterTabIconInactive = { fg = "#a26666" },
		NvimControlCenterBorder = { fg = "#4a6494", bg = "#1a1a22" },
		NvimControlCenterTitle = { fg = "#b65252", bg = "#1a1a22", bold = true },
		NvimControlCenterLineActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		NvimControlCenterLineInactive = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterIconActive = { fg = "#b65252" },
		NvimControlCenterIconInactive = { fg = "#a26666" },
	},
}
```

---

### Full Configuration Example (with groups)

This is an example of how to set up two groups: "General" and "Appearance".

```lua
-- lua/plugins/nvim-control-center.lua

-- First, define your settings groups in separate files (good practice)
local general_settings = {
	name = "general", -- this is the internal key for jump-to
	label = "General", -- this is what is shown as the tab
	icon = "", -- Icons require a Nerd Font
	settings = {
		{
			name = "relativenumber",
			label = "Show relative line numbers",
			type = "bool",
			default = false,
			get = function()
				return vim.opt.relativenumber.get()
			end,
			set = function(val, on_init)
				if on_init then
					vim.opt.relativenumber = val
				else
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						local buf = vim.api.nvim_win_get_buf(win)
						if not utils.is_excluded(buf, {}, { "neo-tree" }) then
							vim.wo[win].relativenumber = val
						end
					end
					data.save("relativenumber", val)
				end
			end,
		},
		{
			name = "cursorline",
			label = "Show cursor line",
			type = "bool",
			default = true,
			get = function()
				return vim.opt.cursorline.get()
			end,
			set = function(val, on_init)
				if on_init then
					vim.opt.cursorline = val
				else
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						local buf = vim.api.nvim_win_get_buf(win)
						if not utils.is_excluded(buf, {}, { "neo-tree" }) then
							vim.wo[win].cursorline = val
						end
					end
					data.save("cursorline", val)
				end
			end,
		},
	},
}

local appearance_settings = {
	name = "appearance",
	label = "Appearance",
	icon = "",
	settings = {
		{
			name = "colorscheme",
			label = "Colorscheme",
			type = "select",
			options = { "lvim-dark", "lvim-darker", "lvim-everforest", "lvim-gruvbox", "lvim-kanagawa", "lvim-light" },
			default = "lvim-darker",
			break_load = true,
			get = function()
				if _G.NVIM_THEME ~= nil then
					return _G.NVIM_THEME
				else
					return "lvim-darker"
				end
			end,
			set = function(val, _)
				_G.NVIM_THEME = val
				vim.cmd("colorscheme " .. val)
				funcs.write_file(_G.global.lvim_path .. "/.configs/lvim/.theme", _G.NVIM_THEME)
				---@diagnostic disable-next-line: undefined-field
				if _G.NVIM_CONTROL_CENTER_WIN and is_control_center_focused(_G.NVIM_CONTROL_CENTER_WIN) then
					vim.cmd("hi Cursor blend=100")
				else
					vim.cmd("hi Cursor blend=0")
				end
				data.save("colorscheme", val)
			end,
		},
	},
}

-- Now, call the setup function with your groups
require("nvim-control-center").setup({
	-- Pass the defined groups here
	groups = {
		general_settings,
		appearance_settings,
	},
	-- You can override default options here as well
	window_size = {
		width = 0.8, -- 80% of the editor width
		height = 0.8, -- 80% of the editor height
	},
	window_size = {
		width = 0.8,
		height = 0.8,
	},
	border = nil, -- Defaults to vim.o.winborder, or "none" if empty.
	icons = {
		is_true = "",
	icons = {
		is_true = "",
		is_false = "",
		is_select = "󱖫",
		is_int = "󰎠",
		is_float = "",
		is_string = "󰬶",
	},
	highlights = {
		NvimControlCenterPanel = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterSeparator = { fg = "#4a6494" },
		NvimControlCenterTabActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		NvimControlCenterTabInactive = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterTabIconActive = { fg = "#b65252" },
		NvimControlCenterTabIconInactive = { fg = "#a26666" },
		NvimControlCenterBorder = { fg = "#4a6494", bg = "#1a1a22" },
		NvimControlCenterTitle = { fg = "#b65252", bg = "#1a1a22", bold = true },
		NvimControlCenterLineActive = { fg = "#1a1a22", bg = "#4a6494", bold = true },
		NvimControlCenterLineInactive = { fg = "#505067", bg = "#1a1a22" },
		NvimControlCenterIconActive = { fg = "#b65252" },
		NvimControlCenterIconInactive = { fg = "#a26666" },
	},
})
```

### Setting Definition

Each setting is a table with the following fields:

| Field     | Type                     | Description                                                                                                                                             |
| :-------- | :----------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `name`    | `string`                 | **Required.** A unique internal identifier. Often matches the option name in `vim.opt`.                                                                 |
| `label`   | `string`                 | **Required.** The name displayed in the user interface.                                                                                                 |
| `type`    | `string`                 | **Required.** The type of setting: `bool`, `boolean`, `string`, `text`, `select`, `int`, `integer`, `float`, `number`.                                  |
| `default` | `any`                    | The default value to be used if no value is found in the database.                                                                                      |
| `icon`    | `string`                 | (Optional) An icon to display for the setting.                                                                                                          |
| `options` | `table`                  | (For `type="select"`) A list of strings with the possible values.                                                                                       |
| `get`     | `function()`             | (Optional) A function that returns the current value of the setting. Used for display in the UI.                                                        |
| `set`     | `function(val, on_init)` | A function that is called when the value is changed. `val` is the new value. **You must call `data.save(setting.name, val)` to persist the new value.** |

#### The set function

The `set` function is the heart of the plugin. It receives a single argument:

1.  `val`: The new value the user has selected.

To persist the new value, **you must call** your own function for saving, for example:

```lua
set = function(val)
	data.save("relativenumber", val)
end
```

If you use extra helpers (like `utils.is_excluded(...)`), you must provide them in your own configuration.

## 🎨 Customizing the Appearance

You can change the colors by redefining any of the following highlight groups in your `colorscheme.lua` or `config.lua`:

```lua
-- Example
vim.api.nvim_set_hl(0, "NvimControlCenterPanel", { bg = "#2D2A2E" })
vim.api.nvim_set_hl(0, "NvimControlCenterTabActive", { bg = "#4A454D", fg = "#CAC5CA" })
```

| Group                              | Description                      |
| :--------------------------------- | :------------------------------- |
| `NvimControlCenterPanel`           | Background of the entire panel   |
| `NvimControlCenterBorder`          | Color of the border              |
| `NvimControlCenterSeparator`       | The line under the tabs          |
| `NvimControlCenterTabActive`       | Active tab                       |
| `NvimControlCenterTabInactive`     | Inactive tab                     |
| `NvimControlCenterTabIconActive`   | Icon in an active tab            |
| `NvimControlCenterTabIconInactive` | Icon in an inactive tab          |
| `NvimControlCenterLineActive`      | Background of the selected row   |
| `NvimControlCenterLineInactive`    | Background of a non-selected row |
| `NvimControlCenterIconActive`      | Icon on the selected row         |
| `NvimControlCenterIconInactive`    | Icon on a non-selected row       |

## 🏃 Tips

- You can combine jump-to-tab and jump-to-setting in your mappings, autocommands, or even via Lua for quick profile scripts!
- Both tab and setting selection are case-sensitive and work for both `name` and `label` (for tabs), and for setting `name` or row (number).

## 📄 License

This project is licensed under the BSD License. See the [LICENSE](LICENSE) file for more details.
