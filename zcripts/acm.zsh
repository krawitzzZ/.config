# AI commit via git + Cursor Agent (no worktrunk).
# Stages → builds prompt from staged diff + branch + the same rules as
# ~/.config/worktrunk/config.toml [commit.generation].template-append →
# agent → git commit.
# Lockfile diffs (package-lock.json, Cargo.lock, go.sum, …) are omitted from
# the prompt via strip-lockfile-prompt.py — same allowlist as worktrunk.
#
# Usage:
#   acm
#   acm --dry-run
#   acm --stage=tracked|all|staged|none
acm() {
  emulate -L zsh
  setopt local_options pipe_fail

  local stage=all dry_run=0

  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run) dry_run=1 ;;
      --stage=all|--stage=tracked|--stage=staged|--stage=none) stage="${arg#--stage=}" ;;
      -h|--help)
        print -r -- "Usage: acm [--dry-run] [--stage=all|tracked|staged|none]"
        return 0
        ;;
      *)
        print -r -- "acm: unknown option: $arg" >&2
        return 1
        ;;
    esac
  done

  command -v git >/dev/null 2>&1 || {
    print -r -- "acm: git not found." >&2
    return 1
  }
  command -v agent >/dev/null 2>&1 || {
    print -r -- "acm: agent (Cursor CLI) not found." >&2
    return 1
  }
  command -v python3 >/dev/null 2>&1 || {
    print -r -- "acm: python3 not found (needed to read worktrunk rules)." >&2
    return 1
  }

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -r -- "acm: not inside a git repository." >&2
    return 1
  }

  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    print -r -- "acm: detached HEAD; checkout a branch first." >&2
    return 1
  }

  local wt_config="${XDG_CONFIG_HOME:-$HOME/.config}/worktrunk/config.toml"
  [[ -f "$wt_config" ]] || {
    print -r -- "acm: missing worktrunk rules at $wt_config" >&2
    return 1
  }

  # Load [commit.generation].template-append and substitute {{ branch }} — same
  # source of truth as `wt cm`, so rules cannot drift.
  local user_guidance
  user_guidance=$(BRANCH="$branch" WT_CONFIG="$wt_config" python3 - <<'PY'
import os, re, sys
from pathlib import Path

text = Path(os.environ["WT_CONFIG"]).read_text()
m = re.search(r'(?m)^\s*template-append\s*=\s*"""(.*?)"""', text, re.S)
if not m:
    print("acm: template-append not found in worktrunk config.", file=sys.stderr)
    sys.exit(1)
append = m.group(1)
# Only the branch placeholder is used in the current rules.
append = append.replace("{{ branch }}", os.environ["BRANCH"])
sys.stdout.write(append)
PY
) || return 1

  local index_path index_backup=""
  index_path=$(git rev-parse --git-path index)
  if (( dry_run )) && [[ -f "$index_path" ]]; then
    # Preview must not leave the index staged.
    index_backup=$(mktemp) || return 1
    cp "$index_path" "$index_backup" || {
      rm -f "$index_backup"
      return 1
    }
  fi

  case "$stage" in
    all)
      git add -A || {
        [[ -n "$index_backup" ]] && cp "$index_backup" "$index_path"
        rm -f "$index_backup"
        print -r -- "acm: git add -A failed." >&2
        return 1
      }
      ;;
    tracked)
      git add -u || {
        [[ -n "$index_backup" ]] && cp "$index_backup" "$index_path"
        rm -f "$index_backup"
        print -r -- "acm: git add -u failed." >&2
        return 1
      }
      ;;
    staged|none) ;;
  esac

  if git diff --cached --quiet; then
    [[ -n "$index_backup" ]] && cp "$index_backup" "$index_path"
    rm -f "$index_backup"
    print -r -- "acm: nothing staged to commit." >&2
    return 1
  fi

  # Same lockfile filter as worktrunk commit.generation — exclude from git
  # pathspecs so huge lock diffs never enter the shell/prompt in the first place.
  local strip_lockfiles="${XDG_CONFIG_HOME:-$HOME/.config}/worktrunk/strip-lockfile-prompt.py"
  [[ -f "$strip_lockfiles" ]] || {
    [[ -n "$index_backup" ]] && cp "$index_backup" "$index_path"
    rm -f "$index_backup"
    print -r -- "acm: missing lockfile filter at $strip_lockfiles" >&2
    return 1
  }

  local -a lock_excludes
  lock_excludes=("${(@f)$(python3 "$strip_lockfiles" --git-excludes)}") || {
    [[ -n "$index_backup" ]] && cp "$index_backup" "$index_path"
    rm -f "$index_backup"
    print -r -- "acm: failed to load lockfile pathspecs." >&2
    return 1
  }

  local git_diff git_diff_stat repo
  # Pathspec: include everything, then exclude lockfiles (git requires a
  # positive path before :(exclude…)).
  git_diff=$(git diff --cached -- . "${lock_excludes[@]}")
  git_diff_stat=$(git diff --cached --stat -- . "${lock_excludes[@]}")
  repo=$(basename "$(git rev-parse --show-toplevel)")

  # Brief note when lockfiles changed but were omitted from the prompt.
  local omitted_lockfiles=""
  local omitted_list
  omitted_list=$(git diff --cached --name-only | python3 "$strip_lockfiles" --filter-names)
  if [[ -n "$omitted_list" ]]; then
    omitted_lockfiles="
<omitted-lockfiles>
Dependency lockfile diffs were omitted from the prompt to save context. They are still part of the commit; do not invent lockfile details. Files:
$(print -r -- "$omitted_list" | sed 's/^/- /')
</omitted-lockfiles>
"
  fi

  if [[ -z "$git_diff" && -n "$omitted_lockfiles" ]]; then
    git_diff="(no non-lockfile changes; see omitted-lockfiles note)"
    git_diff_stat="(lockfile-only commit)"
  fi

  if [[ -n "$index_backup" ]]; then
    cp "$index_backup" "$index_path"
    rm -f "$index_backup"
    index_backup=""
  fi

  # Rules come only from worktrunk template-append (no recent-commits, no
  # conflicting default style that could override them).
  local prompt
  prompt="<task>
Generate the Git commit message for the staged changes below. Analyze silently.
Return only JSON matching: {\"subject\":\"...\",\"body\":\"...\"}.
Use an empty body string when no body is needed.
</task>

<user-guidance>
${user_guidance}
</user-guidance>

<diffstat>
${git_diff_stat}
</diffstat>

<diff>
${git_diff}
</diff>

<context>
Branch: ${branch}
Repo: ${repo}
${omitted_lockfiles}</context>
"

  local model="composer-2.5"
  local message_filter="${XDG_CONFIG_HOME:-$HOME/.config}/worktrunk/plain-commit-message.py"
  local -a llm_cmd
  llm_cmd=(
    timeout --foreground --kill-after=5s 90s
    agent -p --trust --mode ask --model "$model"
  )
  [[ -f "$message_filter" ]] || {
    print -r -- "acm: missing commit-message filter at $message_filter" >&2
    return 1
  }

  if (( dry_run )); then
    print -r -- "PROMPT"
    print -r -- "$prompt"
    print -r -- ""
    print -r -- "COMMAND"
    print -r -- "${(j: :)llm_cmd} | python3 $message_filter"
    print -r -- ""
    print -r -- "MESSAGE"
  else
    print -r -- "◎ Generating commit message..."
  fi

  local raw_response
  raw_response=$(print -r -- "$prompt" | "${llm_cmd[@]}") || {
    local status=$?
    if (( status == 124 || status == 137 )); then
      print -r -- "acm: agent timed out after 90 seconds." >&2
    else
      print -r -- "acm: agent failed (exit $status)." >&2
    fi
    return 1
  }

  # Prefer a naturally-valid message; if the model misbehaves (e.g. subject
  # > 60 chars, which it often does), deterministically repair the SAME
  # response instead of failing or calling the model again.
  local message
  message=$(print -r -- "$raw_response" | python3 "$message_filter" 2>/dev/null) \
    || message=$(print -r -- "$raw_response" | python3 "$message_filter" --repair) \
    || {
      print -r -- "acm: model returned an unusable commit message." >&2
      print -r -- "  raw model output:" >&2
      print -r -- "$raw_response" | sed 's/^/  /' >&2
      return 1
    }

  message=${message##[$' \t\n']##}
  message=${message%%[$' \t\n']##}

  if [[ -z "$message" ]]; then
    print -r -- "acm: empty commit message from agent." >&2
    return 1
  fi

  if (( dry_run )); then
    print -r -- "$message"
    return 0
  fi

  print -r -- "  ${message%%$'\n'*}"
  if [[ "$message" == *$'\n'* ]]; then
    print -r -- "${message#*$'\n'}" | sed 's/^/  /'
  fi

  local msg_file
  msg_file=$(mktemp) || return 1
  print -r -- "$message" >"$msg_file"
  if ! git commit -F "$msg_file"; then
    rm -f "$msg_file"
    print -r -- "acm: git commit failed." >&2
    return 1
  fi
  rm -f "$msg_file"

  local short
  short=$(git rev-parse --short HEAD)
  print -r -- "✓ Committed changes @ $short"
}
