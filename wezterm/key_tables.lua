local wezterm = require 'wezterm'
local act = wezterm.action

return {
  copy_mode = {
    { key = 'Tab',      mods = 'NONE',  action = act.CopyMode 'MoveForwardWord' },
    { key = 'Tab',      mods = 'SHIFT', action = act.CopyMode 'MoveBackwardWord' },
    { key = 'Enter',    mods = 'NONE',  action = act.CopyMode 'MoveToStartOfNextLine' },
    { key = 'Escape',   mods = 'NONE',  action = act.CopyMode 'Close' },
    { key = 'Space',    mods = 'NONE',  action = act.CopyMode { SetSelectionMode = 'Cell' } },
    { key = '$',        mods = 'SHIFT', action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = ',',        mods = 'NONE',  action = act.CopyMode 'JumpReverse' },
    { key = '0',        mods = 'NONE',  action = act.CopyMode 'MoveToStartOfLine' },
    { key = ';',        mods = 'NONE',  action = act.CopyMode 'JumpAgain' },
    { key = 'F',        mods = 'SHIFT', action = act.CopyMode { JumpBackward = { prev_char = false } } },
    { key = 'G',        mods = 'SHIFT', action = act.CopyMode 'MoveToScrollbackBottom' },
    { key = 'H',        mods = 'SHIFT', action = act.CopyMode 'MoveToViewportTop' },
    { key = 'L',        mods = 'SHIFT', action = act.CopyMode 'MoveToViewportBottom' },
    { key = 'M',        mods = 'SHIFT', action = act.CopyMode 'MoveToViewportMiddle' },
    { key = 'O',        mods = 'SHIFT', action = act.CopyMode 'MoveToSelectionOtherEndHoriz' },
    { key = 'T',        mods = 'SHIFT', action = act.CopyMode { JumpBackward = { prev_char = true } } },
    { key = 'V',        mods = 'SHIFT', action = act.CopyMode { SetSelectionMode = 'Line' } },
    { key = '^',        mods = 'SHIFT', action = act.CopyMode 'MoveToStartOfLineContent' },
    { key = 'b',        mods = 'NONE',  action = act.CopyMode 'MoveBackwardWord' },
    { key = 'b',        mods = 'CTRL',  action = act.CopyMode 'PageUp' },
    { key = 'c',        mods = 'CTRL',  action = act.Multiple { act.CopyMode 'ClearPattern', act.CopyMode 'Close' } },
    { key = 'd',        mods = 'CTRL',  action = act.CopyMode { MoveByPage = (0.5) } },
    { key = 'e',        mods = 'NONE',  action = act.CopyMode 'MoveForwardWordEnd' },
    { key = 'f',        mods = 'NONE',  action = act.CopyMode { JumpForward = { prev_char = false } } },
    { key = 'f',        mods = 'CTRL',  action = act.CopyMode 'PageDown' },
    { key = 'g',        mods = 'NONE',  action = act.CopyMode 'MoveToScrollbackTop' },
    { key = 'h',        mods = 'NONE',  action = act.CopyMode 'MoveLeft' },
    { key = 'j',        mods = 'NONE',  action = act.CopyMode 'MoveDown' },
    { key = 'k',        mods = 'NONE',  action = act.CopyMode 'MoveUp' },
    { key = 'l',        mods = 'NONE',  action = act.CopyMode 'MoveRight' },
    { key = 'o',        mods = 'NONE',  action = act.CopyMode 'MoveToSelectionOtherEnd' },
    { key = 'q',        mods = 'NONE',  action = act.Multiple { act.CopyMode 'ClearPattern', act.CopyMode 'Close' } },
    { key = 't',        mods = 'NONE',  action = act.CopyMode { JumpForward = { prev_char = true } } },
    { key = 'u',        mods = 'NONE',  action = act.Multiple { act.ClearSelection, act.CopyMode 'ClearSelectionMode' } },
    { key = 'u',        mods = 'CTRL',  action = act.CopyMode { MoveByPage = (-0.5) } },
    { key = 'v',        mods = 'NONE',  action = act.CopyMode { SetSelectionMode = 'Cell' } },
    { key = 'v',        mods = 'CTRL',  action = act.CopyMode { SetSelectionMode = 'Block' } },
    { key = 'w',        mods = 'NONE',  action = act.CopyMode 'MoveForwardWord' },
    { key = 'y',        mods = 'NONE',  action = act.Multiple { act.CopyTo 'ClipboardAndPrimarySelection', act.ClearSelection, act.CopyMode 'ClearPattern', act.CopyMode 'Close' } },
    { key = 'PageUp',   mods = 'NONE',  action = act.CopyMode 'PageUp' },
    { key = 'PageDown', mods = 'NONE',  action = act.CopyMode 'PageDown' },
    { key = 'End',      mods = 'NONE',  action = act.CopyMode 'MoveToEndOfLineContent' },
    { key = 'Home',     mods = 'NONE',  action = act.CopyMode 'MoveToStartOfLine' },
  },

  search_mode = {
    { key = 'Enter',     mods = 'NONE', action = act.ActivateCopyMode },
    { key = 'Escape',    mods = 'NONE', action = act.Multiple { act.CopyMode 'ClearPattern', act.CopyMode 'Close' } },
    { key = 'q',         mods = 'CTRL', action = act.Multiple { act.CopyMode 'ClearPattern', act.CopyMode 'Close' } },
    { key = 'n',         mods = 'CTRL', action = act.CopyMode 'NextMatch' },
    { key = 'p',         mods = 'CTRL', action = act.CopyMode 'PriorMatch' },
    { key = 'r',         mods = 'CTRL', action = act.CopyMode 'CycleMatchType' },
    { key = 'u',         mods = 'CTRL', action = act.CopyMode 'ClearPattern' },
    { key = 'PageUp',    mods = 'NONE', action = act.CopyMode 'PriorMatchPage' },
    { key = 'PageDown',  mods = 'NONE', action = act.CopyMode 'NextMatchPage' },
    { key = 'UpArrow',   mods = 'NONE', action = act.CopyMode 'PriorMatch' },
    { key = 'DownArrow', mods = 'NONE', action = act.CopyMode 'NextMatch' },
  },

  create_pane_mode = {
    { key = 'h',          action = act.SplitPane { direction = 'Left' }, },
    { key = 'LeftArrow',  action = act.SplitPane { direction = 'Left' }, },

    { key = 'j',          action = act.SplitVertical { domain = 'CurrentPaneDomain' } },
    { key = 'DownArrow',  action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

    { key = 'k',          action = act.SplitPane { direction = 'Up' }, },
    { key = 'UpArrow',    action = act.SplitPane { direction = 'Up' }, },

    { key = 'l',          action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
    { key = 'RightArrow', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },

    { key = 'Escape',     action = 'PopKeyTable' },
  },

  resize_pane_mode = {
    { key = 'LeftArrow',  action = act.AdjustPaneSize { 'Left', 4 } },
    { key = 'h',          action = act.AdjustPaneSize { 'Left', 4 } },

    { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 4 } },
    { key = 'l',          action = act.AdjustPaneSize { 'Right', 4 } },

    { key = 'UpArrow',    action = act.AdjustPaneSize { 'Up', 2 } },
    { key = 'k',          action = act.AdjustPaneSize { 'Up', 2 } },

    { key = 'DownArrow',  action = act.AdjustPaneSize { 'Down', 2 } },
    { key = 'j',          action = act.AdjustPaneSize { 'Down', 2 } },

    { key = 'Escape',     action = 'PopKeyTable' },
  },
}
