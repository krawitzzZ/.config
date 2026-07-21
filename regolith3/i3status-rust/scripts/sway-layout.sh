#!/usr/bin/env bash
# Show the layout of the focused sway container as a single icon, for an
# i3status-rust "custom" block with persistent = true: it prints once, then
# again on every relevant sway event.
#
# In sway a container has exactly ONE layout, and these values are mutually
# exclusive (there is no separate "direction" axis: tabbed/stacked report
# orientation = none):
#   splith  -> 󰕭  md-view_column      (tiled, windows side by side)
#   splitv  -> 󰜩  md-view_sequential  (tiled, windows stacked)
#   tabbed  -> 󰓩  md-tab
#   stacked -> 󰌨  md-layers
#   floating window -> 󰖲  md-window_restore
#
# Glyphs are VictorMono Nerd Font codepoints; tweak to taste.

emit() {
	tree=$(swaymsg -t get_tree 2>/dev/null) || {
		printf '\n'
		return
	}

	# Type of the focused node (to detect floating windows).
	ftype=$(jq -r 'first(.. | objects | select(.focused == true) | .type) // empty' <<<"$tree")
	if [ "$ftype" = "floating_con" ]; then
		printf '%s\n' "󰖲"
		return
	fi

	# Layout of the container that directly holds the focused node.
	layout=$(jq -r 'first(.. | objects
		| select((.nodes[]?.focused == true) or (.floating_nodes[]?.focused == true))
		| .layout) // empty' <<<"$tree")

	case "$layout" in
	splith) printf '%s\n' "󰕭" ;;
	splitv) printf '%s\n' "󰜩" ;;
	tabbed) printf '%s\n' "󰓩" ;;
	stacked) printf '%s\n' "󰌨" ;;
	*) printf '\n' ;;
	esac
}

# Initial value.
emit

# Re-evaluate on focus changes, workspace switches and any keybinding
# (layout is changed via keybindings such as $mod+g / $mod+v / $mod+t ...).
swaymsg -t subscribe -m '["window","workspace","binding"]' 2>/dev/null |
	while read -r _; do
		emit
	done
