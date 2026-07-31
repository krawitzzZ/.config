# Generate a pull request description from branch diffs via OpenCode.
#
# Usage:
#   prd
#   prd --base=feature/foo --target=origin/master --output=pr.md
#   prd --stdout
#   prd --dry-run
prd() {
  emulate -L zsh
  setopt local_options pipe_fail

  local base="" target="origin/master" output="pr.md" dry_run=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --base=*) base="${arg#--base=}" ;;
      --target=*) target="${arg#--target=}" ;;
      --output=*) output="${arg#--output=}" ;;
      --stdout) output="-" ;;
      --dry-run) dry_run=1 ;;
      -h|--help)
        print -r -- "Usage: prd [--base=BRANCH] [--target=BRANCH] [--output=FILE|-] [--stdout] [--dry-run]"
        print -r -- ""
        print -r -- "  --base     Source branch with your changes (default: current branch)"
        print -r -- "  --target   Merge target to compare against (default: origin/master)"
        print -r -- "             When base and target are the same commit, uses local uncommitted changes"
        print -r -- "  --output   Write markdown here (default: pr.md); use - for stdout"
        print -r -- "  --stdout   Same as --output=-"
        print -r -- "  --dry-run  Print prompt and command without calling opencode"
        return 0
        ;;
      *)
        print -r -- "prd: unknown option: $arg" >&2
        return 1
        ;;
    esac
  done

  command -v git >/dev/null 2>&1 || {
    print -r -- "prd: git not found." >&2
    return 1
  }
  command -v opencode >/dev/null 2>&1 || {
    print -r -- "prd: opencode not found." >&2
    return 1
  }
  command -v python3 >/dev/null 2>&1 || {
    print -r -- "prd: python3 not found." >&2
    return 1
  }

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    print -r -- "prd: not inside a git repository." >&2
    return 1
  }

  if [[ -z "$base" ]]; then
    base=$(git symbolic-ref --short HEAD 2>/dev/null) || {
      print -r -- "prd: detached HEAD; pass --base explicitly." >&2
      return 1
    }
  fi

  local description_filter="${XDG_CONFIG_HOME:-$HOME/.config}/worktrunk/plain-pr-description.py"
  [[ -f "$description_filter" ]] || {
    print -r -- "prd: missing PR description filter at $description_filter" >&2
    return 1
  }

  _prd_verify_ref() {
    local ref="$1" label="$2"
    if ! git rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
      print -r -- "prd: ${label} branch does not exist: ${ref}" >&2
      return 1
    fi
  }

  _prd_verify_ref "$base" base || return 1
  _prd_verify_ref "$target" target || return 1

  local base_oid target_oid
  base_oid=$(git rev-parse --verify "${base}^{commit}") || return 1
  target_oid=$(git rev-parse --verify "${target}^{commit}") || return 1

  local mode="branch" commit_count
  commit_count=$(git rev-list --count "${target}..${base}" 2>/dev/null || print -r -- 0)

  local git_name_status git_diff git_diff_stat git_log repo
  if [[ "$base_oid" != "$target_oid" ]] && \
     { (( commit_count > 0 )) || ! git diff --quiet "${target}...${base}"; }; then
    git_name_status=$(git diff --name-status "${target}...${base}")
    git_diff=$(git diff "${target}...${base}")
    git_diff_stat=$(git diff --stat "${target}...${base}")
    git_log=$(git log --oneline "${target}..${base}")
  elif [[ "$base_oid" == "$target_oid" ]] && ! git diff --quiet HEAD; then
    local head_oid
    head_oid=$(git rev-parse HEAD)
    if [[ "$head_oid" != "$base_oid" ]]; then
      print -r -- "prd: local changes mode requires HEAD to match base (${base})." >&2
      return 1
    fi
    mode="working-tree"
    git_name_status=$(git diff --name-status HEAD)
    git_diff=$(git diff HEAD)
    git_diff_stat=$(git diff --stat HEAD)
    git_log="(uncommitted local changes — no commits)"
  else
    if [[ "$base_oid" == "$target_oid" ]]; then
      print -r -- "prd: no changes between ${base} and ${target}, and no local uncommitted changes." >&2
    else
      print -r -- "prd: no changes between ${base} and ${target}." >&2
    fi
    return 1
  fi

  repo=$(basename "$(git rev-parse --show-toplevel)")

  local change_source task_intro diff_scope
  if [[ "$mode" == "working-tree" ]]; then
    change_source="uncommitted local changes on ${base}"
    task_intro="Generate a pull request description in Markdown for the uncommitted local changes below."
    diff_scope="diff"
  else
    change_source="branch diff ${base} → ${target}"
    task_intro="Generate a pull request description in Markdown for the branch diff below."
    diff_scope="diff and commits"
  fi

  local prompt
  prompt="<task>
${task_intro}
Analyze silently. Base the content strictly on the actual ${diff_scope} —
do not invent changes.
Return only the Markdown document, with no preamble, commentary, or code fences.
</task>

<format>
# <concise, imperative PR title>

## Summary
<1-3 sentence overview of what this PR does and why>

## Changes
- <bullet per notable change, grouped logically>
- <omit CHANGELOG.md edits unless they are central to the PR's purpose>

## Notes
- <migrations, breaking changes, follow-ups, or \"None\">
</format>

<rules>
- Keep the title and summary factual and concise.
- Infer intent from commits and the diff; do not speculate beyond the evidence.
- Use complete sentences in Summary and short imperative phrases in Changes.
- If there are no migrations, breaking changes, or follow-ups, write \"- None\" under Notes.
</rules>

<files>
${git_name_status}
</files>

<commits>
${git_log}
</commits>

<diffstat>
${git_diff_stat}
</diffstat>

<diff>
${git_diff}
</diff>

<context>
Base branch: ${base}
Target branch: ${target}
Change source: ${change_source}
Repository: ${repo}
</context>
"

  local model="opencode/deepseek-v4-flash-free"
  local -a llm_cmd
  llm_cmd=(
    timeout --foreground --kill-after=5s 120s
    opencode run --pure -m "$model"
  )

  if (( dry_run )); then
    print -r -- "PROMPT"
    print -r -- "$prompt"
    print -r -- ""
    print -r -- "COMMAND"
    print -r -- "${(j: :)llm_cmd} | python3 $description_filter"
    print -r -- ""
    print -r -- "OUTPUT"
    print -r -- "$([[ "$output" == - ]] && print -r -- stdout || print -r -- "$output")"
    return 0
  fi

  if [[ "$output" != - ]]; then
    if [[ "$mode" == "working-tree" ]]; then
      print -r -- "◎ Generating PR description (local changes on ${base})..."
    else
      print -r -- "◎ Generating PR description (${base} → ${target})..."
    fi
  fi

  local raw_response description
  raw_response=$(print -r -- "$prompt" | "${llm_cmd[@]}") || {
    local status=$?
    if (( status == 124 || status == 137 )); then
      print -r -- "prd: opencode timed out after 120 seconds." >&2
    else
      print -r -- "prd: opencode failed (exit $status)." >&2
    fi
    return 1
  }

  description=$(print -r -- "$raw_response" | python3 "$description_filter" 2>/dev/null) \
    || description=$(print -r -- "$raw_response" | python3 "$description_filter" --repair) \
    || {
      print -r -- "prd: model returned an unusable PR description." >&2
      print -r -- "  raw model output:" >&2
      print -r -- "$raw_response" | sed 's/^/  /' >&2
      return 1
    }

  if [[ -z "${description//[$' \t\n']}" ]]; then
    print -r -- "prd: empty PR description from opencode." >&2
    return 1
  fi

  if [[ "$output" == - ]]; then
    print -r -- "$description"
  else
    print -r -- "$description" >"$output" || {
      print -r -- "prd: failed to write ${output}." >&2
      return 1
    }
    if [[ "$mode" == "working-tree" ]]; then
      print -r -- "✓ Wrote PR description to ${output} (local changes on ${base})"
    else
      print -r -- "✓ Wrote PR description to ${output} (${base} → ${target})"
    fi
  fi
}
