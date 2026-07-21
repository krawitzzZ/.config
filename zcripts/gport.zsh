# Port your current branch's net changes onto a fresh branch off a base branch
# (default: origin/master), without dragging along a long-lived, far-behind branch.
# It diffs only what YOUR branch introduced since it forked from the base (three-dot
# diff, so the base's extra commits are ignored), then re-applies that patch on a new
# branch cut from the up-to-date base.
#
# Usage: gport [base-branch] [new-branch-name]
#   gport                         # base origin/master, auto-named new branch
#   gport origin/develop          # base origin/develop, auto-named new branch
#   gport origin/master feat-x    # base origin/master, new branch named 'feat-x'
gport() {
  emulate -L zsh

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "gport: not inside a git repository." >&2
    return 1
  }

  local current_branch
  current_branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "gport: detached HEAD, checkout a branch first." >&2
    return 1
  }

  # Refuse to run with a dirty tree so no uncommitted work is lost during checkout.
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "gport: working tree not clean. Commit or stash your changes first." >&2
    return 1
  fi

  local base_branch="${1:-origin/master}"
  local new_branch="${2:-${current_branch}-onto-${base_branch##*/}}"

  # Refresh the base ref when it is a remote-tracking branch (e.g. origin/master).
  if [[ "$base_branch" == */* ]]; then
    git fetch "${base_branch%%/*}" "${base_branch#*/}" || {
      echo "gport: could not fetch $base_branch." >&2
      return 1
    }
  fi

  git rev-parse --verify --quiet "$base_branch" >/dev/null || {
    echo "gport: base branch '$base_branch' not found." >&2
    return 1
  }

  # Three-dot diff: only the changes this branch made since it diverged from the base,
  # ignoring the commits the base moved ahead. --binary keeps binary files intact.
  local patch_file
  patch_file=$(mktemp -t "gport.XXXXXX.patch")
  git diff --binary "${base_branch}...${current_branch}" >"$patch_file"

  if [[ ! -s "$patch_file" ]]; then
    echo "gport: no net differences between '$current_branch' and '$base_branch'. Nothing to port." >&2
    rm -f "$patch_file"
    return 1
  fi

  git checkout --no-track -b "$new_branch" "$base_branch" || {
    echo "gport: could not create branch '$new_branch' from '$base_branch'." >&2
    rm -f "$patch_file"
    return 1
  }

  # --3way falls back to a real merge when the base already touched the same lines.
  if git apply --3way --whitespace=nowarn "$patch_file"; then
    echo "gport: applied your changes onto new branch '$new_branch' (based on $base_branch)."
    echo "gport: review with 'git status' / 'git diff', then commit."
  else
    echo "gport: applied with conflicts, resolve them then 'git add' the files." >&2
  fi
  echo "gport: patch saved at $patch_file"
}

# Completion: suggest remote-tracking branches (origin/*, etc.) for the base branch.
_gport() {
  # Note: do NOT use `emulate -L zsh` here. It resets options to zsh defaults
  # and clobbers the matching state the completion system sets up, which breaks
  # matching of slash-containing prefixes (e.g. `gport origin/RA<TAB>`).

  # Only offer completions inside a git work tree.
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  case $CURRENT in
    2)
      # First argument: the base branch. Complete remote-tracking branches.
      local -a remote_branches
      remote_branches=(${(f)"$(git for-each-ref --format='%(refname:short)' refs/remotes 2>/dev/null)"})
      # Keep only real remote branches (those containing a '/'). This drops the
      # bare remote name that git reports for the symbolic <remote>/HEAD ref
      # (e.g. 'origin'), which otherwise collapses completion to just 'origin'.
      remote_branches=(${(M)remote_branches:#*/*})
      _describe -t remote-branches 'base branch' remote_branches
      ;;
    3)
      # Second argument: free-form new branch name, nothing to complete.
      _message -e new-branch 'new branch name'
      ;;
  esac
}

# Register the completion only when the completion system is loaded.
if (( $+functions[compdef] )); then
  compdef _gport gport
fi
