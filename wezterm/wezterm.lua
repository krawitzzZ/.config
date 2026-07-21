local wezterm = require 'wezterm'
local keys = require 'keys'
local keyTables = require 'key_tables'

local config = wezterm.config_builder()
local fontMedium = wezterm.font_with_fallback {
  { family = 'VictorMono Nerd Font',    weight = 'Medium' },
  { family = 'JetBrainsMono Nerd Font', weight = 'Medium' },
  { family = 'FiraCode Nerd Font',      weight = 'Medium' },
  { family = 'Victor Mono',             weight = 'Medium' },
}

-- Show which key table is active in the status area
wezterm.on('update-right-status', function(window, pane)
  local name = window:active_key_table()
  if name then
    name = 'MODE: ' .. name:gsub('_mode$', '') .. '  '
  end
  window:set_right_status(name or '')
end)

config.initial_cols = 160
config.initial_rows = 40

config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 450
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'
config.font_size = 12.5
config.font = fontMedium
config.warn_about_missing_glyphs = false -- sometimes glyphs are missing
config.color_scheme = 'Github (base16)'

config.enable_tab_bar = true
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
-- config.integrated_title_button_style = "Gnome"
-- config.window_decorations = "RESIZE|TITLE|INTEGRATED_BUTTONS"
config.window_frame = {
  font_size = 13.0,
  active_titlebar_bg = '#343434',
  inactive_titlebar_bg = '#343434',
}

config.colors = {
  tab_bar = {
    inactive_tab_edge = '#343434',
  },
}
config.window_padding = {
  left = '1cell',
  right = '1cell',
  top = '0.5cell',
  bottom = '0.5cell',
}
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.8,
}

config.leader = { key = 'phys:Space', mods = 'CTRL|ALT', timeout_milliseconds = 1000 }
config.disable_default_key_bindings = true
config.keys = keys
config.key_tables = keyTables

return config
