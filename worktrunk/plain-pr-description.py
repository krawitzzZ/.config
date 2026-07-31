#!/usr/bin/env python3
"""Extract a PR description markdown document from LLM output.

Strict mode (default) rejects responses that lack a recognizable title and
required sections. Repair mode (--repair) unwraps fences and keeps the first
plausible markdown document.
"""

import re
import sys

REQUIRED_SECTIONS = ("## Summary", "## Changes", "## Notes")
REPAIR = "--repair" in sys.argv[1:]
META = re.compile(
    r"\b(?:here is|below is|pull request description|I wrote|the diff shows)\b",
    flags=re.IGNORECASE,
)


def fail(reason: str) -> "None":
    print(f"pr-description filter: {reason}", file=sys.stderr)
    raise SystemExit(2)


def unwrap(text: str) -> str:
    text = text.strip()
    fence = re.fullmatch(r"```(?:markdown|md)?\s*\n(.*?)\n```", text, flags=re.DOTALL)
    if fence:
        return fence.group(1).strip()
    return text


def extract_document(text: str) -> str:
    text = unwrap(text)
    start = text.find("# ")
    if start == -1:
        fail("no markdown title found")
    text = text[start:].rstrip() + "\n"

    if META.search(text) and not REPAIR:
        fail("response contains model commentary")
    return text


def validate(text: str) -> None:
    if not text.startswith("# "):
        fail("document must start with a level-1 heading")
    if len(text.splitlines()[0]) <= 2:
        fail("empty PR title")
    for section in REQUIRED_SECTIONS:
        if section not in text:
            fail(f"missing required section: {section}")


def main() -> None:
    document = extract_document(sys.stdin.read())
    try:
        validate(document)
    except SystemExit:
        if not REPAIR:
            raise
    sys.stdout.write(document)


main()
