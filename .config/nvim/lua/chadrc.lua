local options = {
  base46 = {
    lazy = false,
    theme = "solarized_light", -- default theme
    hl_add = {},
    hl_override = require "byda.config.highlights",
    integrations = {},
    changed_themes = {},
    transparency = false,
    theme_toggle = { "onedark", "one_light" },
  },

  ui = {
    cmp = {
      enabled = true,
      icons_left = false, -- only for non-atom styles!
      style = "default", -- default/flat_light/flat_dark/atom/atom_colored
      abbr_maxwidth = 60,
      format_colors = {
        tailwind = true, -- will work for css lsp too
        icon = "󱓻",
      },
    },

    telescope = {}, -- borderless / bordered
    statusline = {
      lazy = false,
      enabled = true,
      theme = "default", -- default/vscode/vscode_colored/minimal
      -- default/round/block/arrow separators work only for default statusline theme
      -- round and block will work for minimal theme only
      separator_style = "default",
      order = nil,
      modules = nil,
    },
    tabufline = {
      enabled = false,
    },
  },
  nvdash = {
    enabled = false,
  },
  term = {
    enabled = false,
  },
  lsp = {
    enabled = false,
  },
  cheatsheet = {
    enabled = false,
  },
  mason = {
    enanbled = false,
  },
  colorify = {
    enabled = false,
  },
}

local status, chadrc = pcall(require, "chadrc")
return vim.tbl_deep_extend("force", options, status and chadrc or {})

