typeset -g ZED_THREADS_PY="${${(%):-%x}:A:h}/zed_threads.py"

_zedEditorRunning() {
  if ! command -v pgrep >/dev/null 2>&1; then
    echo "zedThreadCleanup: pgrep is required to see whether zed is running" >&2
    return 0
  fi
  pgrep -x zed-editor >/dev/null
}

_zedThreadPy() {
  python3 "$ZED_THREADS_PY" "$@"
}

zedThreadCleanup() {
  emulate -L zsh
  setopt local_options pipefail

  if _zedEditorRunning; then
    echo "zedThreadCleanup: quit zed first. The editor has the workspace database open." >&2
    return 1
  fi

  if ! command -v fzf >/dev/null 2>&1; then
    echo "zedThreadCleanup: fzf is not on PATH" >&2
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "zedThreadCleanup: python3 is required to update zed's sqlite databases" >&2
    return 1
  fi

  local output
  output=$(_zedThreadPy list) || return $?
  if [[ -z "$output" ]]; then
    echo "no zed threads"
    return 0
  fi

  local -a rows
  rows=("${(@f)output}")

  local pick
  pick=$(mktemp) || return $?

  local preview
  preview="python3 ${(q)ZED_THREADS_PY} preview {f}"

  FZF_DEFAULT_OPTS= FZF_PICK_FILE=$pick fzf \
    --multi \
    --delimiter='\t' \
    --with-nth='7,9,8,6,10' \
    --layout=reverse \
    --prompt='delete > ' \
    --header=$'Tab toggles a row. Enter deletes toggled rows. Esc cancels.\nupdated\tprofile\tfolder\tbody\ttitle' \
    --preview="$preview" \
    --preview-window='down:8:wrap' \
    --bind='enter:execute-silent(test "$FZF_SELECT_COUNT" -gt 0 && cat {+f} > "$FZF_PICK_FILE")+abort' \
    < <(printf '%s\n' "${rows[@]}")
  local fzf_status=$?

  if [[ ! -s "$pick" ]]; then
    rm -f "$pick"
    if (( fzf_status == 130 || fzf_status == 1 )); then
      echo "cancelled"
      return 0
    fi
    echo "zedThreadCleanup: fzf exited $fzf_status" >&2
    return "$fzf_status"
  fi

  if _zedEditorRunning; then
    rm -f "$pick"
    echo "zedThreadCleanup: zed started while the list was open. Nothing was deleted." >&2
    return 1
  fi

  local -a picked
  picked=("${(@f)$(<"$pick")}")
  rm -f "$pick"
  _zedThreadPy delete "${picked[@]}"
}
