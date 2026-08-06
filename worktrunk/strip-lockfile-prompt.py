#!/usr/bin/env python3
"""Strip dependency lockfile noise from LLM commit / squash prompts.

Used by:
  - worktrunk [commit.generation] command (stdin filter before the agent)
  - acm (git pathspecs via --git-excludes, or stdin filter)

Modes:
  (default)   Read a prompt on stdin; rewrite <diffstat> / <diff> to omit
              known lockfiles; leave a one-line note of what was omitted.
  --git-excludes
              Print git pathspec excludes (one per line) for `git diff -- . …`.
  --filter-names
              Read paths on stdin; print those whose basename is a lockfile.
"""

from __future__ import annotations

import re
import sys
from pathlib import PurePosixPath


# Basename allowlist — common package-manager lock / freeze files.
# Keep this curated: not every `*.lock` is a dependency lockfile.
LOCKFILE_BASENAMES = frozenset(
    {
        # JavaScript / Node
        "package-lock.json",
        "npm-shrinkwrap.json",
        "yarn.lock",
        "pnpm-lock.yaml",
        "bun.lock",
        "bun.lockb",
        "deno.lock",
        "shrinkwrap.yaml",
        # Rust
        "Cargo.lock",
        # Go
        "go.sum",
        # Haskell
        "cabal.project.freeze",
        "stack.yaml.lock",
        # Nix
        "flake.lock",
        # Python
        "poetry.lock",
        "Pipfile.lock",
        "pdm.lock",
        "uv.lock",
        "requirements.lock",
        # Other ecosystems
        "composer.lock",
        "Gemfile.lock",
        "mix.lock",
        "pubspec.lock",
        "Podfile.lock",
        "Package.resolved",
        "renv.lock",
        "conan.lock",
        "gradle.lockfile",
        "packages.lock.json",  # NuGet
        "paket.lock",
    }
)

DIFF_GIT_RE = re.compile(r"^diff --git a/(.*) b/(.*)$")
STAT_LINE_RE = re.compile(r"^(\s*)(.*?)(\s+\|\s+.*)$")
TAG_RE = re.compile(
    r"(<(diffstat|diff)>)(.*?)(</\2>)",
    flags=re.DOTALL | re.IGNORECASE,
)


def is_lockfile(path: str) -> bool:
    name = PurePosixPath(path.strip()).name
    return name in LOCKFILE_BASENAMES


def git_exclude_pathspecs() -> list[str]:
    """Pathspecs that exclude lockfiles at any depth."""
    return [
        f":(exclude,glob)**/{name}" for name in sorted(LOCKFILE_BASENAMES)
    ]


def strip_unified_diff(text: str) -> tuple[str, list[str]]:
    """Drop lockfile file sections from a unified diff. Return (diff, omitted)."""
    if not text.strip():
        return text, []

    lines = text.splitlines(keepends=True)
    out: list[str] = []
    omitted: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = DIFF_GIT_RE.match(line.rstrip("\n"))
        if not m:
            out.append(line)
            i += 1
            continue

        a_path, b_path = m.group(1), m.group(2)
        # Consume this file's hunk through the next diff --git (or EOF).
        j = i + 1
        while j < len(lines) and not DIFF_GIT_RE.match(lines[j].rstrip("\n")):
            j += 1

        if is_lockfile(a_path) or is_lockfile(b_path):
            # Prefer the non-/dev/null side for the note.
            path = b_path if b_path != "/dev/null" else a_path
            if path not in omitted:
                omitted.append(path)
        else:
            out.extend(lines[i:j])
        i = j

    return "".join(out), omitted


def strip_diffstat(text: str) -> tuple[str, list[str]]:
    """Drop lockfile rows from `git diff --stat` output. Return (stat, omitted)."""
    if not text.strip():
        return text, []

    out: list[str] = []
    omitted: list[str] = []
    summary_re = re.compile(r"^\s*\d+\s+files? changed\b")
    for line in text.splitlines(keepends=True):
        raw = line.rstrip("\n")
        m = STAT_LINE_RE.match(raw)
        if m and "|" in raw:
            path = m.group(2).rstrip()
            if is_lockfile(path):
                if path not in omitted:
                    omitted.append(path)
                continue
        # Drop the stale "N files changed…" footer if we removed rows; a
        # remaining non-lockfile hunk list is enough for the model.
        if omitted and summary_re.match(raw):
            continue
        out.append(line)
    return "".join(out), omitted


def merge_omitted(*lists: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for items in lists:
        for item in items:
            if item not in seen:
                seen.add(item)
                result.append(item)
    return result


def filter_prompt(prompt: str) -> str:
    omitted_all: list[str] = []

    def repl(match: re.Match[str]) -> str:
        nonlocal omitted_all
        open_tag, kind, body, close_tag = (
            match.group(1),
            match.group(2).lower(),
            match.group(3),
            match.group(4),
        )
        if kind == "diffstat":
            new_body, omitted = strip_diffstat(body)
        else:
            new_body, omitted = strip_unified_diff(body)
        omitted_all = merge_omitted(omitted_all, omitted)

        if omitted and not new_body.strip():
            new_body = (
                "\n(no non-lockfile changes in this section; "
                "see omitted-lockfiles note)\n"
            )
        elif new_body and not new_body.endswith("\n"):
            new_body += "\n"

        return f"{open_tag}{new_body}{close_tag}"

    filtered = TAG_RE.sub(repl, prompt)

    if omitted_all:
        note = (
            "\n<omitted-lockfiles>\n"
            "Dependency lockfile diffs were omitted from the prompt to save context. "
            "They are still part of the commit; do not invent lockfile details. "
            "Files:\n"
            + "".join(f"- {p}\n" for p in omitted_all)
            + "</omitted-lockfiles>\n"
        )
        if "</context>" in filtered:
            filtered = filtered.replace("</context>", note + "</context>", 1)
        else:
            filtered = filtered.rstrip() + "\n" + note

    return filtered


def main() -> None:
    args = sys.argv[1:]
    if "--git-excludes" in args:
        for spec in git_exclude_pathspecs():
            print(spec)
        return
    if "--filter-names" in args:
        for line in sys.stdin:
            path = line.strip()
            if path and is_lockfile(path):
                print(path)
        return

    sys.stdout.write(filter_prompt(sys.stdin.read()))


if __name__ == "__main__":
    main()
