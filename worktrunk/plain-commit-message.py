#!/usr/bin/env python3
"""Extract and validate a plain-text commit message from LLM output."""

import json
import re
import sys


SUBJECT = re.compile(
    r"^(?:"
    r"\[(?:PSWH|BFFTRAC|IN)-\d+\]"
    r"|\[INNOLAB\]"
    r"|(?:feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|boyscout)"
    r"(?:\([^)]+\))?"
    r"):\s+(.+)$"
)
OUTER_DELIMITERS = {("`", "`"), ('"', '"'), ("'", "'")}
META_BODY = re.compile(
    r"\b(?:the branch|the diff|I chose|this commit message|no body needed|"
    r"the subject is|the format is)\b",
    flags=re.IGNORECASE,
)


def unwrap(text: str) -> str:
    """Remove wrappers around a complete response, not backticks in its body."""
    text = text.strip()
    fence = re.fullmatch(r"```[^\n]*\n(.*?)\n```", text, flags=re.DOTALL)
    if fence:
        text = fence.group(1).strip()
    while len(text) >= 2 and (text[0], text[-1]) in OUTER_DELIMITERS:
        text = text[1:-1].strip()
    return text


def normalize_subject(line: str) -> str | None:
    """Return a normalized valid subject, or None for prose/non-subject lines."""
    line = unwrap(line)
    match = SUBJECT.fullmatch(line)
    if not match:
        return None

    description = match.group(1).strip().removesuffix(".")
    if not description:
        return None

    # Small free models often follow conventional-commit lowercase examples
    # despite the explicit local rule. Enforce the rule deterministically.
    description = description[0].upper() + description[1:]
    subject = f"{line[:match.start(1)]}{description}"

    if len(subject) > 60:
        print(
            f"commit-message filter: subject exceeds 60 characters: {subject!r}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    return subject


raw = sys.stdin.read().strip()
message = unwrap(raw)

def parse_json_response(text: str) -> tuple[str, str] | None:
    """Find one valid subject/body object, tolerating accidental outer prose."""
    decoder = json.JSONDecoder()
    objects: list[dict[str, object]] = []
    for index, char in enumerate(text):
        if char != "{":
            continue
        try:
            value, _ = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            continue
        if (
            isinstance(value, dict)
            and set(value) == {"subject", "body"}
            and isinstance(value["subject"], str)
            and isinstance(value["body"], str)
        ):
            objects.append(value)

    if not objects:
        return None
    if len(objects) != 1:
        print(
            f"commit-message filter: expected one JSON result, found {len(objects)}",
            file=sys.stderr,
        )
        raise SystemExit(2)

    value = objects[0]
    raw_subject = value["subject"]
    if "\n" in raw_subject or "\r" in raw_subject:
        print("commit-message filter: subject contains a newline", file=sys.stderr)
        raise SystemExit(2)
    subject = normalize_subject(raw_subject)
    if subject is None:
        print("commit-message filter: invalid commit subject", file=sys.stderr)
        raise SystemExit(2)

    body = value["body"].strip()
    if "```" in body or META_BODY.search(body):
        print("commit-message filter: body contains model commentary", file=sys.stderr)
        raise SystemExit(2)
    return subject, body


json_result = parse_json_response(message)
if json_result:
    subject, body = json_result
    result = subject if not body else f"{subject}\n\n{body}"
else:
    lines = message.splitlines()

    # Backward-compatible plain-text path. Preserve a clean optional body.
    subject = normalize_subject(lines[0]) if lines else None
    if subject:
        body = "\n".join(lines[1:]).strip()
        body = re.sub(r"^```[^\n]*\n?", "", body)
        body = re.sub(r"\n?```$", "", body).strip()
        if META_BODY.search(body):
            print(
                "commit-message filter: body contains model commentary",
                file=sys.stderr,
            )
            raise SystemExit(2)
        result = subject if not body else f"{subject}\n\n{body}"
    else:
        # Misbehaving model: extract exactly one valid subject from prose/fences
        # and discard all commentary. Refuse ambiguity instead of committing it.
        candidates = [
            candidate
            for line in lines
            if (candidate := normalize_subject(line)) is not None
        ]
        candidates = list(dict.fromkeys(candidates))
        if len(candidates) != 1:
            print(
                "commit-message filter: expected exactly one valid commit subject, "
                f"found {len(candidates)}",
                file=sys.stderr,
            )
            raise SystemExit(2)
        result = candidates[0]

sys.stdout.write(result + "\n")
